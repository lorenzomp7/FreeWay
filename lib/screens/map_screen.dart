import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/disabled_parking.dart';
import '../models/entrance_report.dart';
import '../models/contributions.dart';
import '../models/obstacle.dart';
import '../models/place_accessibility.dart';
import '../models/route_option.dart';
import '../models/route_preferences.dart';
import '../models/travel_mode.dart';
import '../services/along_route_service.dart';
import '../services/disabled_parking_service.dart';
import '../services/contribution_log_service.dart';
import '../services/entrance_report_service.dart';
import '../services/geo_utils.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../services/obstacle_alerts.dart';
import '../services/nearby_accessible_service.dart';
import '../services/obstacle_service.dart';
import '../services/compass/compass.dart';
import '../services/heading.dart';
import '../services/offline/connectivity.dart';
import '../services/offline/offline_route_service.dart';
import '../services/position_filter.dart';
import '../services/opening_hours.dart';
import '../services/place_accessibility_service.dart';
import '../services/recent_places_service.dart';
import '../services/saved_places_service.dart';
import '../services/routing_service.dart';
import '../services/trip_resume_service.dart';
import '../services/trip_share_service.dart';
import '../services/weather_service.dart';
import '../services/speech_input.dart';
import '../services/thanks_notifier.dart';
import '../services/voice_report_matcher.dart';
import '../services/tts_service.dart';
import '../services/voice_guidance.dart';
import '../theme/app_theme.dart';
import '../widgets/along_route_widgets.dart';
import '../widgets/contributions_sheet.dart';
import '../widgets/weekly_review_sheet.dart';
import '../widgets/map_widgets.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/navigation_prompts.dart';
import '../widgets/obstacle_sheets.dart';
import '../widgets/place_sheet.dart';
import '../widgets/route_details_sheets.dart';
import '../widgets/route_options_sheet.dart';
import '../widgets/saved_places_widgets.dart';
import '../widgets/search_panel.dart';
import '../widgets/top_bar.dart';
import '../widgets/trip_share_widgets.dart';
import '../widgets/voice_settings_sheet.dart';

/// Schermata principale: mappa, ricerca percorso, ostacoli e navigazione.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final RoutingService _routingService = RoutingService();
  final GeocodingService _geocodingService = GeocodingService();
  final PlaceAccessibilityService _accessibilityService =
      PlaceAccessibilityService();
  final AlongRouteService _alongRouteService = AlongRouteService();
  final WeatherService _weatherService = WeatherService();
  final DisabledParkingService _parkingService = DisabledParkingService();

  /// Livello della mappa con i parcheggi per disabili nella zona inquadrata.
  bool _showParkingLayer = false;
  bool _isLoadingParkings = false;
  List<DisabledParking> _layerParkings = [];
  Timer? _parkingDebounce;
  int _parkingRequest = 0;

  /// Zoom minimo per chiedere i parcheggi della zona inquadrata.
  static const double _parkingMinZoom = 14;

  /// In auto, durante la navigazione: l'auto è già al parcheggio e da qui
  /// si prosegue in sedia a rotelle.
  bool _passedParking = false;

  /// Avviso meteo per il percorso calcolato (pioggia, neve, ghiaccio, caldo).
  String? _weatherWarning;

  /// Luoghi trovati lungo il percorso scelto, per categoria (bagni,
  /// panchine, fontanelle), come "Search along route" di Google Maps.
  Map<AlongRouteCategory, List<AlongRoutePlace>> _along = {};
  final Set<AlongRouteCategory> _alongLoading = {};

  /// Tappe intermedie scelte dall'utente, in ordine ("Add stop").
  List<AlongRoutePlace> _stops = [];
  static const int _maxStops = 3;
  final ObstacleService _obstacleService = ObstacleService(
    FirebaseFirestore.instance,
  );
  final EntranceReportService _entranceService = EntranceReportService(
    FirebaseFirestore.instance,
  );
  final ArrivalQuestionPolicy _arrivalPolicy = ArrivalQuestionPolicy();
  final ThanksNotifier _thanksNotifier = ThanksNotifier();

  /// Quando si è aiutato sulle segnalazioni altrui, per "La tua settimana".
  final ContributionLogService _contributionLog = ContributionLogService();
  bool _contributionLogLoaded = false;
  bool _obstaclesLoaded = false;
  bool _weeklyReviewChecked = false;
  final SpeechInput _speechInput = SpeechInput();
  final NearbyAccessibleService _nearbyService = NearbyAccessibleService();
  NearbySearch _nearby = const NearbySearch();
  int _nearbyRequest = 0;
  bool _isListening = false;

  /// Segnalazione detta a voce in attesa di conferma: punto, frase capita e
  /// tipo riconosciuto.
  ({LatLng point, String heard, String type})? _voiceReport;

  /// Una posizione stimata dalla rete non sostituisce un buon fix GPS
  /// ottenuto da poco.
  final PositionFilter _userFix = PositionFilter(
    staleAfter: const Duration(minutes: 2),
    maxSpeed: 50,
  );
  final NavigationService _navigationService = NavigationService();
  final TtsService _ttsService = TtsService();
  final TripShareService _tripShare = TripShareService(
    FirebaseFirestore.instance,
  );

  /// "Salva per l'uso senza rete" e stato della rete.
  final OfflineRouteService _offlineRoute = OfflineRouteService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOffline = false;

  /// Bussola: cono sul pallino e mappa orientata dove si guarda.
  final Compass _compass = Compass();
  StreamSubscription<double>? _compassSubscription;
  final HeadingSmoother _headingSmoother = HeadingSmoother();
  double? _deviceHeading;
  DateTime _lastHeadingUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  /// "Direzione in alto" invece di "nord in alto"; resta sul dispositivo.
  bool _headingUp = false;
  double _mapRotation = 0;
  static const String _headingUpKey = 'freeway.heading_up';

  /// Avanzamento del salvataggio (fatte, totali), `null` se fermo.
  (int, int)? _offlineProgress;

  /// Il percorso le cui tile sono state salvate.
  List<LatLng>? _offlineSavedFor;

  /// "Opzioni del percorso": pendenza, cordoli, fondo e velocità.
  RoutePreferences _routePrefs = RoutePreferences.defaults;

  double _zoom = 13;
  LatLng _center = const LatLng(45.4642, 9.19); // Milano
  LatLng? _userLocation;

  /// Raggio di incertezza della posizione, in metri, se noto.
  double? _userAccuracy;

  /// Durante la navigazione: nessun aggiornamento GPS da troppo tempo.
  bool _gpsSignalLost = false;
  Timer? _gpsWatchdog;
  static const Duration _gpsSilenceLimit = Duration(seconds: 30);

  List<LatLng> _routePoints = [];
  List<RouteOption> _routes = [];
  int _selectedRouteIndex = 0;

  LatLng? _startPoint;
  LatLng? _endPoint;

  bool _isCalculating = false;
  bool _isRecalculating = false;
  DateTime? _lastRecalculation;
  final VoiceGuidance _voiceGuidance = VoiceGuidance();

  /// Ostacoli di cui si è già avvisato in questa navigazione.
  final Set<String> _announcedObstacleIds = {};
  DateTime? _lastObstacleWarningAt;
  bool _isLocatingStart = false;
  bool _isLocatingEnd = false;
  bool _isLocatingUser = false;
  bool _isNavigating = false;
  NavigationUpdate? _navigationUpdate;
  RouteStep? _navigationFirstStep;
  bool _navigationGpsFailed = false;
  String _voiceLanguage = 'it';
  StreamSubscription<NavigationUpdate>? _navigationSubscription;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocus = FocusNode(debugLabel: 'partenza');
  final FocusNode _endFocus = FocusNode(debugLabel: 'arrivo');
  List<SearchItem> _startItems = [];
  List<SearchItem> _endItems = [];
  String? _noResultsStart;
  String? _noResultsEnd;
  bool _isSearchExpanded = true;

  final RecentPlacesService _recentPlaces = RecentPlacesService();
  final SavedPlacesService _savedPlaces = SavedPlacesService();
  List<SavedPlace> _saved = [];

  /// Navigazione interrotta da riprendere ("Still heading to…?").
  final TripResumeService _tripResume = TripResumeService();
  PendingTrip? _pendingTrip;
  List<Map<String, dynamic>> _recents = [];

  /// Ricerca, luogo trovato o indicazioni, come in Google Maps.
  SearchPhase _stage = SearchPhase.search;

  /// Il luogo cercato, mostrato nella sua scheda e ritrovato chiudendo le
  /// indicazioni.
  Map<String, dynamic>? _selectedPlace;
  TravelMode _travelMode = TravelMode.wheelchair;

  /// Accessibilità della destinazione cercata, da OpenStreetMap.
  PlaceAccessibility? _placeAccessibility;
  bool _isLoadingAccessibility = false;
  int _accessibilityRequest = 0;

  /// Punto del luogo cercato. Nelle indicazioni l'arrivo può spostarsi
  /// sull'ingresso accessibile; chiudendole torna qui.
  LatLng? _destinationPlacePoint;

  /// `true` o `false` mentre si sceglie sulla mappa la partenza o l'arrivo.
  bool? _choosingOnMapFor;
  bool _showReportHint = true;

  List<Obstacle> _obstacles = [];

  /// Tutte le segnalazioni lette, anche quelle nascoste: servono a "Le tue
  /// segnalazioni" per dire perché una non si vede più.
  List<Obstacle> _allObstacles = [];

  /// Ostacolo su cui si sta chiedendo "C'è ancora?" durante la navigazione.
  Obstacle? _verifyPrompt;
  Timer? _verifyTimer;

  /// Ostacolo su cui si chiede "Si riesce a passare in sedia a rotelle?".
  Obstacle? _passPrompt;

  /// Destinazione su cui chiedere "Com'era l'ingresso?", mentre la domanda
  /// è aperta.
  LatLng? _arrivalPrompt;
  Timer? _arrivalTimer;
  bool _arrivalHandled = false;

  /// Ultimo punto del tracciato su cui si era prima di uscirne.
  LatLng? _lastOnRoutePoint;

  /// Punto in cui si è lasciato il percorso, mentre è aperta la domanda
  /// "Hai cambiato strada per un ostacolo?" (una volta per viaggio).
  LatLng? _deviationPrompt;
  Timer? _deviationTimer;
  bool _deviationAsked = false;

  /// Risposte sull'ingresso vicino al luogo aperto nella scheda.
  EntranceSummary _entranceSummary = const EntranceSummary();
  int _entranceRequest = 0;

  /// Ostacoli già chiesti in questa navigazione: si chiede una volta sola.
  final Set<String> _askedObstacleIds = {};

  /// Ostacoli noti all'inizio della navigazione o già valutati: quelli nuovi
  /// sul percorso fanno cercare un'alternativa.
  final Set<String> _knownObstacleIds = {};

  /// Avviso di un nuovo ostacolo sul percorso e l'eventuale alternativa.
  Obstacle? _routeAlertObstacle;
  List<RouteOption>? _routeAlertRoutes;
  bool _routeAlertSearching = false;
  int _routeAlertExtraMinutes = 0;
  String _selectedCategory = 'Tutti';
  final List<String> _categories = [
    'Tutti',
    'Dislivello e pavimentazione',
    'Ingresso e passaggio',
    'Sicurezza',
    'Ostacoli temporanei',
  ];

  List<Obstacle> get _filteredObstacles {
    if (_selectedCategory == 'Tutti') return _obstacles;
    return _obstacles.where((o) => o.category == _selectedCategory).toList();
  }

  int _countForCategory(String category) {
    if (category == 'Tutti') return _obstacles.length;
    return _obstacles.where((o) => o.category == category).length;
  }

  @override
  void initState() {
    super.initState();
    _locateUser();
    // Il pannello mostra recenti e suggerimenti solo per il campo attivo.
    _startFocus.addListener(_onFocusChanged);
    _endFocus.addListener(_onFocusChanged);
    _recentPlaces.load().then((recents) {
      if (mounted) setState(() => _recents = recents);
    });
    _savedPlaces.load().then((saved) {
      if (mounted) setState(() => _saved = saved);
    });
    _ttsService.loadSettings();
    RoutePreferences.load().then((prefs) {
      if (mounted) setState(() => _routePrefs = prefs);
    });
    _offlineRoute.load().then((_) {
      if (mounted) setState(() {});
    });
    _isOffline = !_connectivity.isOnline;
    _connectivitySubscription = _connectivity.changes.listen(_onConnectivity);
    if (_compass.isSupported) {
      _compassSubscription = _compass.headings.listen(_onCompassHeading);
    }
    SharedPreferences.getInstance()
        .then((prefs) {
          if (mounted && prefs.getBool(_headingUpKey) == true) {
            setState(() => _headingUp = true);
          }
        })
        .catchError((_) {});
    _tripResume.load().then((trip) {
      if (mounted && trip != null) setState(() => _pendingTrip = trip);
    });
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      _contributionLog.load(userId).then((_) {
        _contributionLogLoaded = true;
        _maybeShowWeeklyReview();
      });
    }
    _obstacleService.listen((obstacles) {
      // Gli ostacoli temporanei non confermati da tempo non compaiono né
      // sulla mappa né nel calcolo dei percorsi.
      // Spariscono anche gli ostacoli che almeno due persone hanno detto
      // non esserci più.
      final active = obstacles.where((o) => !o.isHidden()).toList();
      if (!mounted) return;
      setState(() {
        _obstacles = active;
        _allObstacles = obstacles;
        _obstaclesLoaded = true;
      });
      _checkNewObstaclesOnRoute(active);
      _announceNewThanks(obstacles);
      _maybeShowWeeklyReview();
    });
    _mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      _center = event.camera.center;
      _mapRotation = event.camera.rotation;
      _zoom = event.camera.zoom;
    });
  }

  @override
  void dispose() {
    if (_isNavigating) _keepScreenOn(false);
    _ttsService.stop();
    _ttsService.reset();
    _navigationSubscription?.cancel();
    _verifyTimer?.cancel();
    _arrivalTimer?.cancel();
    _deviationTimer?.cancel();
    _speechInput.cancel();
    _gpsWatchdog?.cancel();
    _navigationService.dispose();
    if (_tripShare.isSharing) unawaited(_tripShare.stop());
    _tripShare.dispose();
    _connectivitySubscription?.cancel();
    _compassSubscription?.cancel();
    _offlineRoute.dispose();
    _obstacleService.dispose();
    _geocodingService.dispose();
    _accessibilityService.dispose();
    _alongRouteService.dispose();
    _weatherService.dispose();
    _parkingService.dispose();
    _parkingDebounce?.cancel();
    _startController.dispose();
    _endController.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {
      // Toccando la barra compatta il pannello si riapre.
      if (_startFocus.hasFocus || _endFocus.hasFocus) _isSearchExpanded = true;
    });
  }

  void _showSnack(
    String message, {
    Color? iconColor,
    required IconData icon,
    SnackBarAction? action,
  }) {
    final colors = AppColors.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? colors.surfaceElevated
            : AppPalette.snackBarLight,
        duration: Duration(seconds: action == null ? 4 : 6),
        action: action,
        content: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message, IconData icon) =>
      _showSnack(message, icon: icon);

  // --- Ricerca indirizzi ---------------------------------------------------

  void _onSearchChanged(String query, bool isStart) {
    // Come in Google Maps i luoghi salvati vengono prima, poi la cronologia.
    final savedMatches = [
      for (final saved in _savedPlaces.matching(query))
        SearchItem(saved.place, saved: saved),
    ];
    final recentMatches = [
      ...savedMatches,
      for (final place in _recentPlaces.matching(query))
        if (!savedMatches.any(
          (s) => RecentPlacesService.isSamePlace(s.place, place),
        ))
          SearchItem(place, isRecent: true),
    ];
    setState(() {
      if (isStart) {
        _startPoint = null;
        _startItems = recentMatches;
        _noResultsStart = null;
      } else {
        _endPoint = null;
        _endItems = recentMatches;
        _noResultsEnd = null;
        _clearAccessibility();
        // Si sta cercando un altro luogo: la scheda del precedente si chiude.
        if (_stage == SearchPhase.place) {
          _stage = SearchPhase.search;
          _selectedPlace = null;
        }
      }
      _isCalculating = false;
      _routes = [];
      _routePoints = [];
    });
    _geocodingService.searchDebounced(
      query,
      (results) {
        if (!mounted) return;
        setState(() {
          final items = _mergeResults(recentMatches, results);
          final noResults = items.isEmpty && query.trim().length >= 2
              ? query.trim()
              : null;
          if (isStart) {
            _startItems = items;
            _noResultsStart = noResults;
          } else {
            _endItems = items;
            _noResultsEnd = noResults;
          }
        });
      },
      onError: () {
        if (!mounted) return;
        _showError(
          'Ricerca temporaneamente non disponibile. Riprova.',
          Icons.error_outline_rounded,
        );
      },
      near: _center,
    );
  }

  /// Prima i luoghi della cronologia, poi i suggerimenti non già presenti.
  List<SearchItem> _mergeResults(
    List<SearchItem> recent,
    List<Map<String, dynamic>> results,
  ) {
    return [
      ...recent,
      for (final place in results)
        if (!recent.any((r) => RecentPlacesService.isSamePlace(r.place, place)))
          SearchItem(place),
    ];
  }

  /// Invio sulla tastiera: come in Google Maps si va al primo risultato.
  Future<void> _onSubmitted(bool isStart) async {
    final controller = isStart ? _startController : _endController;
    final query = controller.text.trim();
    if (query.length < 2 || (isStart ? _startPoint : _endPoint) != null) return;
    final items = isStart ? _startItems : _endItems;
    if (items.isNotEmpty) {
      _selectSuggestion(items.first.place, isStart);
      return;
    }
    _geocodingService.cancelSearch();
    setState(() => isStart ? _isLocatingStart = true : _isLocatingEnd = true);
    try {
      final results = await _geocodingService.search(query, near: _center);
      if (!mounted || controller.text.trim() != query) return;
      if (results.isNotEmpty) {
        _selectSuggestion(results.first, isStart);
      } else {
        setState(() {
          if (isStart) {
            _noResultsStart = query;
          } else {
            _noResultsEnd = query;
          }
        });
      }
    } on Exception {
      if (!mounted) return;
      _showError(
        'Ricerca temporaneamente non disponibile. Riprova.',
        Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) {
        setState(
          () => isStart ? _isLocatingStart = false : _isLocatingEnd = false,
        );
      }
    }
  }

  /// Testo del campo per un luogo scelto: il nome e la città.
  String _fieldText(Map<String, dynamic> place) {
    final label = formatPlace(place);
    final address = place['address'] as Map<String, dynamic>?;
    final city =
        address?['city'] ??
        address?['town'] ??
        address?['village'] ??
        address?['municipality'];
    if (city == null || city == label.title) return label.title;
    return '${label.title}, $city';
  }

  void _selectSuggestion(Map<String, dynamic> place, bool isStart) {
    _geocodingService.cancelSearch();
    final lat = double.parse(place['lat'].toString());
    final lon = double.parse(place['lon'].toString());
    final point = LatLng(lat, lon);
    FocusScope.of(context).unfocus();
    setState(() {
      _setPoint(isStart, point, _fieldText(place));
      if (_stage != SearchPhase.directions) {
        // Come in Google Maps: la mappa va sul luogo, lo evidenzia e mostra
        // la sua scheda; il percorso si chiede con "Indicazioni".
        _stage = SearchPhase.place;
        _selectedPlace = place;
      }
    });
    unawaited(
      _recentPlaces.add(place).then((recents) {
        if (mounted) setState(() => _recents = recents);
      }),
    );
    if (!isStart) _loadAccessibility(place, point);

    if (_stage == SearchPhase.place) {
      _mapController.move(point, 17);
    } else if (_startPoint != null && _endPoint != null) {
      _calculateRoute();
    } else {
      // Manca ancora l'altro estremo: il cursore va lì.
      (isStart ? _endFocus : _startFocus).requestFocus();
    }
  }

  /// "Casa" o "Lavoro" sotto la casella: va al luogo, oppure spiega come
  /// impostarlo.
  void _openSavedShortcut(SavedKind kind, bool isStart) {
    final saved = kind == SavedKind.home
        ? _savedPlaces.home
        : _savedPlaces.work;
    if (saved != null) {
      _selectSuggestion(saved.place, isStart);
      return;
    }
    final name = kind == SavedKind.home ? 'Casa' : 'Lavoro';
    // Il cursore torna nella casella, pronto per scrivere l'indirizzo. Sul
    // web il tocco sul pulsante sposta il focus della pagina: si toglie e si
    // rimette, così la tastiera torna a scrivere nella casella.
    final focus = isStart ? _startFocus : _endFocus;
    focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
    _showSnack(
      'Cerca il tuo indirizzo, poi nella sua scheda premi «Salva» e scegli '
      '«$name».',
      icon: savedKindIcon(kind),
    );
  }

  Future<void> _removeSaved(SavedPlace saved) async {
    final list = await _savedPlaces.remove(saved);
    if (!mounted) return;
    setState(() {
      _saved = list;
      _startItems = _startItems.where((i) => i.saved != saved).toList();
      _endItems = _endItems.where((i) => i.saved != saved).toList();
    });
  }

  /// "Salva" nella scheda del luogo.
  Future<void> _savePlace() async {
    final place = _selectedPlace;
    if (place == null) return;
    final choice = await showSavePlaceSheet(
      context,
      placeName: formatPlace(place).title,
      current: _savedPlaces.savedAs(place),
      home: _savedPlaces.home,
      work: _savedPlaces.work,
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case SaveAs(:final kind, :final label):
        final list = await _savedPlaces.save(place, kind, label: label);
        if (!mounted) return;
        setState(() => _saved = list);
        final savedAs = list.first.label;
        _showSnack(
          'Salvato come «$savedAs». Lo trovi toccando la casella di ricerca.',
          iconColor: AppColors.of(context).success,
          icon: Icons.check_circle_rounded,
        );
      case RemoveSaved(:final saved):
        await _removeSaved(saved);
        if (!mounted) return;
        _showSnack(
          '«${saved.label}» tolto dai salvati.',
          icon: Icons.bookmark_remove_outlined,
        );
    }
  }

  Future<void> _removeRecent(Map<String, dynamic> place) async {
    final recents = await _recentPlaces.remove(place);
    if (!mounted) return;
    setState(() {
      _recents = recents;
      _startItems = _startItems
          .where(
            (i) =>
                !i.isRecent || !RecentPlacesService.isSamePlace(i.place, place),
          )
          .toList();
      _endItems = _endItems
          .where(
            (i) =>
                !i.isRecent || !RecentPlacesService.isSamePlace(i.place, place),
          )
          .toList();
    });
  }

  /// Passa alle indicazioni. Come in Google Maps la partenza è la tua
  /// posizione, se nota, e il percorso si calcola subito; altrimenti il
  /// cursore va sul campo che manca.
  void _openDirections() {
    _geocodingService.cancelSearch();
    final location = _userLocation;
    setState(() {
      _stage = SearchPhase.directions;
      _isSearchExpanded = true;
      _endItems = [];
      _noResultsEnd = null;
      if (_startPoint == null && location != null) {
        _setPoint(true, location, 'La tua posizione');
      }
      _applyEntrance();
    });
    if (_startPoint != null && _endPoint != null) {
      _calculateRoute();
    } else if (_endPoint == null) {
      _endFocus.requestFocus();
    } else {
      _startFocus.requestFocus();
    }
  }

  /// Chiude le indicazioni: si torna alla scheda del luogo (o alla ricerca)
  /// e la partenza e i percorsi vengono tolti.
  void _closeDirections() {
    _geocodingService.cancelSearch();
    FocusScope.of(context).unfocus();
    setState(() {
      _stage = _endPoint != null && _selectedPlace != null
          ? SearchPhase.place
          : SearchPhase.search;
      // Nella scheda il segnaposto torna sul luogo, non sull'ingresso.
      if (_stage == SearchPhase.place) {
        _endPoint = _destinationPlacePoint ?? _endPoint;
      }
      _isSearchExpanded = true;
      _startController.clear();
      _startItems = [];
      _noResultsStart = null;
      _startPoint = null;
      _endItems = [];
      _isCalculating = false;
      _routes = [];
      _routePoints = [];
      _selectedRouteIndex = 0;
      _stops = [];
      _along = {};
    });
    final end = _endPoint;
    if (end != null) _mapController.move(end, 17);
  }

  /// Chiude la scheda del luogo e torna alla casella di ricerca vuota.
  void _closePlace() {
    _geocodingService.cancelSearch();
    FocusScope.of(context).unfocus();
    setState(() {
      _stage = SearchPhase.search;
      _selectedPlace = null;
      _endPoint = null;
      _endController.clear();
      _endItems = [];
      _noResultsEnd = null;
      _clearAccessibility();
    });
  }

  void _setPoint(bool isStart, LatLng point, String text) {
    if (isStart) {
      _startPoint = point;
      _startController.text = text;
      _startItems = [];
      _noResultsStart = null;
    } else {
      _endPoint = point;
      _endController.text = text;
      _endItems = [];
      _noResultsEnd = null;
      _clearAccessibility();
    }
  }

  // --- Accessibilità e ingressi della destinazione ------------------------

  /// Da chiamare dentro setState: dimentica l'accessibilità della
  /// destinazione precedente e ignora le risposte ancora in arrivo.
  void _clearAccessibility() {
    _accessibilityRequest++;
    _placeAccessibility = null;
    _isLoadingAccessibility = false;
    _destinationPlacePoint = null;
  }

  /// Legge da OpenStreetMap accessibilità e ingressi della destinazione,
  /// come le voci "Accessible entrance" della scheda di Google Maps.
  void _loadAccessibility(Map<String, dynamic> place, LatLng point) {
    final request = ++_accessibilityRequest;
    final supported = PlaceAccessibilityService.supports(place);
    _loadEntranceSummary(point);
    setState(() {
      _destinationPlacePoint = point;
      _placeAccessibility = null;
      _isLoadingAccessibility = supported;
    });
    if (!supported) return;
    _accessibilityService.load(place, point).then((info) {
      if (!mounted || request != _accessibilityRequest) return;
      var moved = false;
      setState(() {
        _placeAccessibility = info;
        _isLoadingAccessibility = false;
        if (_stage == SearchPhase.directions) moved = _applyEntrance();
      });
      if (moved && _startPoint != null && !_isNavigating) _calculateRoute();
    });
  }

  /// Le risposte "Com'era l'ingresso?" di chi è già arrivato a [point].
  void _loadEntranceSummary(LatLng point) {
    final request = ++_entranceRequest;
    _entranceSummary = const EntranceSummary();
    _entranceService.near(point).then((summary) {
      if (!mounted || request != _entranceRequest) return;
      setState(() => _entranceSummary = summary);
    });
  }

  /// Da chiamare dentro setState: se c'è un ingresso accessibile e l'arrivo
  /// è ancora il punto del luogo, l'arrivo diventa l'ingresso.
  bool _applyEntrance() {
    final entrance = _placeAccessibility?.bestEntrance;
    final placePoint = _destinationPlacePoint;
    if (entrance == null || placePoint == null || _endPoint != placePoint) {
      return false;
    }
    _endPoint = entrance.position;
    return true;
  }

  /// Toccando un ingresso sulla mappa il percorso arriva lì.
  void _chooseEntrance(PlaceEntrance entrance) {
    setState(() => _endPoint = entrance.position);
    if (_stage != SearchPhase.directions) {
      _openDirections();
    } else if (_startPoint != null) {
      _calculateRoute();
    }
  }

  void _clearPoint({required bool isStart}) {
    _geocodingService.cancelSearch();
    setState(() {
      if (isStart) {
        _startController.clear();
        _startItems = [];
        _noResultsStart = null;
        _startPoint = null;
      } else {
        _endController.clear();
        _endItems = [];
        _noResultsEnd = null;
        _endPoint = null;
        _clearAccessibility();
        if (_stage == SearchPhase.place) {
          _stage = SearchPhase.search;
          _selectedPlace = null;
        }
      }
      _routePoints = [];
      _isCalculating = false;
      _routes = [];
      _isSearchExpanded = true;
    });
    // Come in Google Maps la "x" lascia il cursore nel campo, con le
    // ricerche recenti sotto.
    (isStart ? _startFocus : _endFocus).requestFocus();
  }

  void _swapPoints() {
    _geocodingService.cancelSearch();
    setState(() {
      final start = _startPoint;
      _startPoint = _endPoint;
      _endPoint = start;
      final startText = _startController.text;
      _startController.text = _endController.text;
      _endController.text = startText;
      _startItems = [];
      _endItems = [];
      _noResultsStart = null;
      _noResultsEnd = null;
      _clearAccessibility();
      // Al contrario le tappe si incontrano nell'ordine inverso.
      _stops = _stops.reversed.toList();
    });
    if (_startPoint != null && _endPoint != null) _calculateRoute();
  }

  void _setTravelMode(TravelMode mode) {
    if (mode == _travelMode) return;
    setState(() => _travelMode = mode);
    if (_startPoint != null && _endPoint != null) _calculateRoute();
  }

  /// Mette nel campo il testo copiato e lo cerca subito.
  Future<void> _pasteAddress({required bool isStart}) async {
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      text = null;
    }
    if (!mounted) return;
    // Solo la prima riga: un indirizzo copiato da un messaggio basta.
    final pasted = (text ?? '').trim().split('\n').first.trim();
    if (pasted.isEmpty) {
      _showError(
        'Negli appunti non c\'è un testo da incollare.',
        Icons.content_paste_off_rounded,
      );
      return;
    }
    final value = pasted.length > 150 ? pasted.substring(0, 150) : pasted;
    final controller = isStart ? _startController : _endController;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    (isStart ? _startFocus : _endFocus).requestFocus();
    _onSearchChanged(value, isStart);
  }

  // --- Scegli sulla mappa -------------------------------------------------

  void _chooseOnMap({required bool isStart}) {
    _geocodingService.cancelSearch();
    FocusScope.of(context).unfocus();
    final current = isStart ? _startPoint : _endPoint;
    setState(() => _choosingOnMapFor = isStart);
    if (current != null) _mapController.move(current, 17);
  }

  Future<void> _confirmChooseOnMap() async {
    final isStart = _choosingOnMapFor;
    if (isStart == null) return;
    final point = _mapController.camera.center;
    setState(() {
      _choosingOnMapFor = null;
      _setPoint(isStart, point, 'Punto sulla mappa');
    });
    if (_startPoint != null && _endPoint != null) {
      _calculateRoute();
    } else {
      (isStart ? _endFocus : _startFocus).requestFocus();
    }
    final address = await _geocodingService.reverse(point);
    if (!mounted || address == null || address.isEmpty) return;
    // Il punto potrebbe essere già cambiato nel frattempo.
    if ((isStart ? _startPoint : _endPoint) != point) return;
    setState(
      () => (isStart ? _startController : _endController).text = address,
    );
  }

  // --- Scheda del luogo ---------------------------------------------------

  /// "Avvia" della scheda: percorso dalla tua posizione e navigazione subito.
  /// "Riprendi": percorso dalla posizione attuale alla destinazione salvata,
  /// con lo stesso mezzo, e navigazione subito.
  Future<void> _resumeTrip() async {
    final trip = _pendingTrip;
    if (trip == null) return;
    setState(() {
      _pendingTrip = null;
      _travelMode = trip.mode;
      _stage = SearchPhase.directions;
      _selectedPlace = null;
      _setPoint(false, trip.destination, trip.label);
    });
    if (_userLocation == null) await _locateUser(showErrors: true);
    if (!mounted) return;
    final location = _userLocation;
    if (location == null) {
      _openDirections();
      return;
    }
    setState(() => _setPoint(true, location, 'La tua posizione'));
    await _calculateRoute(startNavigation: true);
  }

  void _dismissTrip() {
    setState(() => _pendingTrip = null);
    unawaited(_tripResume.clear());
  }

  Future<void> _startFromPlace() async {
    if (_userLocation == null) await _locateUser(showErrors: true);
    if (!mounted) return;
    final location = _userLocation;
    if (location == null) {
      // Senza posizione si sceglie la partenza a mano.
      _openDirections();
      return;
    }
    setState(() {
      _stage = SearchPhase.directions;
      _setPoint(true, location, 'La tua posizione');
      _applyEntrance();
    });
    await _calculateRoute(startNavigation: true);
  }

  Future<void> _sharePlace() async {
    final point = _endPoint;
    final place = _selectedPlace;
    if (point == null || place == null) return;
    final lat = point.latitude.toStringAsFixed(6);
    final lon = point.longitude.toStringAsFixed(6);
    final text =
        '${_fieldText(place)}\n'
        'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=18/$lat/$lon';
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      _showSnack(
        'Link del luogo copiato negli appunti.',
        iconColor: AppColors.of(context).success,
        icon: Icons.check_circle_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile copiare il link.',
        Icons.error_outline_rounded,
      );
    }
  }

  int _obstaclesNear(LatLng point, {double radius = 150}) => _obstacles
      .where((o) => haversineDistance(o.position, point) <= radius)
      .length;

  // --- Percorsi ------------------------------------------------------------

  Future<void> _calculateRoute({bool startNavigation = false}) async {
    final start = _startPoint;
    final end = _endPoint;
    final mode = _travelMode;
    if (start == null || end == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isCalculating = true;
      _routes = [];
      _along = {};
    });
    try {
      final routes = await _getRoutes(start, end, mode);
      if (!mounted ||
          _startPoint != start ||
          _endPoint != end ||
          _travelMode != mode) {
        return;
      }
      setState(() {
        _routes = routes;
        _selectedRouteIndex = 0;
        _routePoints = routes.isNotEmpty ? routes.first.points : [];
        _isCalculating = false;
        _isSearchExpanded = routes.isEmpty;
      });
      _fitRoute();
      unawaited(_loadWeather(start));
      if (routes.isNotEmpty && routes.first.ignoresPreferences) {
        _showSnack(
          'Nessun percorso rispetta tutte le tue opzioni: ti mostro il '
          'migliore senza limiti. Controlla le difficoltà nella scheda.',
          icon: Icons.warning_amber_rounded,
        );
      }
      if (startNavigation) _startNavigation();
    } catch (_) {
      if (!mounted ||
          _startPoint != start ||
          _endPoint != end ||
          _travelMode != mode) {
        return;
      }
      setState(() => _isCalculating = false);
      _showError(
        'Non è stato possibile calcolare il percorso. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  /// Percorsi con il mezzo scelto. In auto cerca prima i parcheggi per
  /// disabili vicino alla destinazione; durante la navigazione resta sul
  /// parcheggio scelto e, una volta lasciata l'auto, prosegue in sedia a
  /// rotelle.
  Future<List<RouteOption>> _getRoutes(
    LatLng from,
    LatLng to,
    TravelMode mode, {
    bool duringNavigation = false,
  }) async {
    if (mode != TravelMode.car) {
      return _routingService.getRoutes(
        from,
        to,
        _obstacles,
        mode: mode,
        via: [for (final stop in _stops) stop.position],
        preferences: _routePrefs,
      );
    }
    if (duringNavigation) {
      if (_passedParking) {
        return _routingService.getRoutes(
          from,
          to,
          _obstacles,
          mode: TravelMode.wheelchair,
          preferences: _routePrefs,
        );
      }
      final current = _routes.isEmpty
          ? null
          : _routes[_selectedRouteIndex].parking;
      if (current != null) {
        return _routingService.getCarRoutes(
          from,
          to,
          _obstacles,
          parkings: [current],
          preferences: _routePrefs,
        );
      }
    }
    final parkings =
        await _parkingService.near(to) ?? const <DisabledParking>[];
    return _routingService.getCarRoutes(
      from,
      to,
      _obstacles,
      parkings: parkings,
      preferences: _routePrefs,
    );
  }

  // --- Parcheggi per disabili sulla mappa ---------------------------------

  void _toggleParkingLayer() {
    final show = !_showParkingLayer;
    setState(() {
      _showParkingLayer = show;
      if (!show) {
        _layerParkings = [];
        _isLoadingParkings = false;
        _parkingRequest++;
      }
    });
    if (show) {
      if (_mapController.camera.zoom < _parkingMinZoom) {
        _showSnack(
          'Avvicina la mappa per vedere i parcheggi per disabili.',
          icon: Icons.zoom_in_rounded,
        );
      }
      _refreshParkings();
    }
  }

  void _onMapMoved() {
    if (!_showParkingLayer) return;
    _parkingDebounce?.cancel();
    _parkingDebounce = Timer(
      const Duration(milliseconds: 700),
      _refreshParkings,
    );
  }

  Future<void> _refreshParkings() async {
    if (!_showParkingLayer || !mounted) return;
    final camera = _mapController.camera;
    if (camera.zoom < _parkingMinZoom) return;
    final bounds = camera.visibleBounds;
    final request = ++_parkingRequest;
    setState(() => _isLoadingParkings = true);
    final found = await _parkingService.inBounds(
      bounds.southWest,
      bounds.northEast,
    );
    if (!mounted || request != _parkingRequest) return;
    setState(() {
      _isLoadingParkings = false;
      if (found != null) _layerParkings = found;
    });
    if (found == null) {
      _showError(
        'Non è stato possibile caricare i parcheggi. Riprova tra poco.',
        Icons.cloud_off_rounded,
      );
    } else if (found.isEmpty) {
      _showSnack(
        'In questa zona OpenStreetMap non segna parcheggi per disabili.',
        icon: Icons.local_parking_rounded,
      );
    }
  }

  void _openParking(DisabledParking parking) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ParkingMarker(label: 'Parcheggio per disabili'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Parcheggio per disabili',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(parking.summary),
              if (_userLocation != null) ...[
                const SizedBox(height: 4),
                Text(
                  'A ${_formatMeters(haversineDistance(_userLocation!, parking.position))} da te',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Dati di OpenStreetMap: controlla sul posto i cartelli e '
                'gli orari.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.directions_car_rounded),
                  label: const Text('Indicazioni in auto'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _directionsToParking(parking);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMeters(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
      : '${meters.round()} m';

  void _directionsToParking(DisabledParking parking) {
    setState(() {
      _travelMode = TravelMode.car;
      _selectedPlace = null;
      _stops = [];
      _setPoint(false, parking.position, parking.name ?? 'Parcheggio per disabili');
    });
    _openDirections();
  }

  /// "Opzioni del percorso" nella scheda dei percorsi.
  Future<void> _openRoutePreferences() async {
    final chosen = await showRoutePreferencesSheet(
      context,
      _routePrefs,
      showWheelchairOptions: _travelMode == TravelMode.wheelchair,
    );
    if (chosen == null || !mounted) return;
    final before = _routePrefs;
    setState(() => _routePrefs = chosen);
    unawaited(chosen.save());
    if (_routes.isEmpty) return;
    if (!chosen.sameRestrictions(before) &&
        _travelMode == TravelMode.wheelchair) {
      // Pendenza, cordoli o fondo diversi: serve un nuovo percorso.
      await _calculateRoute();
    } else if (chosen.pace != before.pace) {
      // Cambia solo la velocità: si correggono i tempi.
      final ratio = chosen.pace.factor / before.pace.factor;
      setState(() {
        _routes = [for (final r in _routes) r.withPace(ratio)];
        _routePoints = _routes[_selectedRouteIndex].points;
      });
    }
  }

  /// "Elenco indicazioni" del percorso scelto.
  void _showRouteSteps() {
    if (_routes.isEmpty) return;
    showRouteStepsSheet(
      context,
      _routes[_selectedRouteIndex],
      language: _voiceLanguage,
    );
  }

  /// Riassunto delle opzioni scelte, se diverse da quelle predefinite.
  String? get _routePrefsSummary {
    final prefs = _routePrefs;
    if (_travelMode != TravelMode.wheelchair) {
      return prefs.pace == TravelPace.normal
          ? null
          : 'Velocità ${prefs.pace.label.toLowerCase()}';
    }
    if (prefs.hasDefaultRestrictions && prefs.pace == TravelPace.normal) {
      return null;
    }
    return 'Opzioni: ${prefs.summary}';
  }

  void _selectRoute(int index) {
    if (index < 0 || index >= _routes.length) return;
    setState(() {
      _selectedRouteIndex = index;
      _routePoints = _routes[index].points;
      _along = {};
    });
    _fitRoute();
  }

  Future<void> _loadWeather(LatLng position) async {
    final warning = await _weatherService.warningFor(position);
    if (!mounted || _startPoint != position) return;
    setState(() => _weatherWarning = warning);
  }

  /// "Cerca lungo il percorso" di Google Maps: bagni accessibili, panchine
  /// e fontanelle vicino al percorso scelto. Toccando di nuovo una categoria
  /// già cercata i suoi segnaposto spariscono.
  Future<void> _searchAlong(AlongRouteCategory category) async {
    if (_routes.isEmpty) return;
    if (_along.containsKey(category)) {
      setState(() => _along = {..._along}..remove(category));
      return;
    }
    final route = _routes[_selectedRouteIndex];
    setState(() => _alongLoading.add(category));
    final places = await _alongRouteService.search(category, route.points);
    if (!mounted) return;
    setState(() {
      _alongLoading.remove(category);
      // Il percorso potrebbe essere cambiato nel frattempo.
      if (places != null &&
          _routes.contains(route) &&
          _routes[_selectedRouteIndex] == route) {
        _along = {..._along, category: places};
      }
    });
    if (places == null) {
      _showError(
        'Ricerca lungo il percorso non disponibile in questo momento. Riprova.',
        Icons.error_outline_rounded,
      );
    } else if (places.isEmpty) {
      _showSnack(
        'Nessun risultato per ${category.plural} su OpenStreetMap lungo il '
        'percorso.',
        icon: alongRouteIcon(category),
      );
    }
  }

  /// Scheda del luogo lungo il percorso con "Aggiungi come tappa".
  Future<void> _openAlongPlace(AlongRoutePlace place) async {
    final already = _stops.any((s) => s.position == place.position);
    final String? reason = _isNavigating
        ? 'Le tappe si aggiungono prima di avviare la navigazione.'
        : already
        ? 'È già una tappa del percorso.'
        : _stops.length >= _maxStops
        ? 'Puoi aggiungere al massimo $_maxStops tappe.'
        : null;
    final add = await showAlongPlaceSheet(
      context,
      place,
      canAddStop: reason == null,
      reason: reason,
    );
    if (add != true || !mounted) return;
    setState(
      () =>
          _stops = [..._stops, place]
            ..sort((a, b) => a.metersFromStart.compareTo(b.metersFromStart)),
    );
    _calculateRoute();
  }

  void _removeStop(int index) {
    if (index < 0 || index >= _stops.length) return;
    setState(() => _stops = [..._stops]..removeAt(index));
    if (_startPoint != null && _endPoint != null) _calculateRoute();
  }

  void _closeRoutes() {
    setState(() {
      _along = {};
      _stops = [];
      _routes = [];
      _routePoints = [];
      _selectedRouteIndex = 0;
      _isSearchExpanded = true;
    });
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    final points = List<LatLng>.of(_routePoints);
    if (_startPoint != null) points.add(_startPoint!);
    if (_endPoint != null) points.add(_endPoint!);
    // In basso c'è la scheda dei percorsi: il tragitto va nello spazio
    // libero sopra, senza superare metà schermo sui telefoni piccoli.
    final height = MediaQuery.sizeOf(context).height;
    final bottom = math.min(_routeSheetHeight + 110, height * 0.62);
    final top = math.min(200.0, height * 0.25);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: EdgeInsets.fromLTRB(48, top, 48, bottom),
      ),
    );
  }

  /// Altezza stimata della scheda dei percorsi.
  /// "Potrebbe essere chiuso quando arrivi", con gli orari della
  /// destinazione presi da OpenStreetMap.
  String? get _arrivalWarning {
    if (_routes.isEmpty) return null;
    final route = _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)];
    return arrivalOpeningWarning(
      _placeAccessibility?.openingHours,
      DateTime.now().add(Duration(seconds: route.duration.round())),
    );
  }

  double get _routeSheetHeight =>
      404 +
      (_arrivalWarning == null ? 0 : 22) +
      (_routePrefsSummary == null ? 0 : 18) +
      (_routes.isNotEmpty &&
              _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)]
                  .ignoresPreferences
          ? 22
          : 0) +
      32.0 * _selectedRouteWarningCount +
      (_stops.isEmpty ? 0 : 44) +
      (_weatherWarning == null ? 0 : 36);

  // --- Navigazione ---------------------------------------------------------

  void _startNavigation() {
    if (_routes.isEmpty) return;
    final route = _routes[_selectedRouteIndex];
    if (route.steps.isEmpty) {
      _showError(
        'Questo percorso non contiene indicazioni passo-passo.',
        Icons.directions_walk_rounded,
      );
      return;
    }
    setState(() {
      _isNavigating = true;
      _passedParking = false;
      _navigationFirstStep = route.steps.first;
      _navigationGpsFailed = false;
      _askedObstacleIds.clear();
      _announcedObstacleIds.clear();
      _arrivalHandled = false;
      _closeArrivalPromptInState();
      _lastOnRoutePoint = null;
      _deviationAsked = false;
      _closeDeviationPromptInState();
      _knownObstacleIds
        ..clear()
        ..addAll(_obstacles.map((o) => o.id));
      _clearRouteAlert();
    });
    _keepScreenOn(true);
    _gpsSignalLost = false;
    _restartGpsWatchdog();
    // L'avviso meteo si dice una volta, alla partenza.
    final weather = _weatherWarning;
    if (weather != null && _voiceLanguage == 'it') {
      _ttsService.speak(weather, _voiceLanguage);
    }
    final destination = _endPoint;
    if (destination != null) {
      _pendingTrip = null;
      unawaited(
        _tripResume.save(
          PendingTrip(
            destination: destination,
            label: _endController.text.isEmpty
                ? 'destinazione'
                : _endController.text,
            mode: _travelMode,
            startedAt: DateTime.now(),
          ),
        ),
      );
    }
    _navigationSubscription?.cancel();
    _navigationSubscription = _navigationService.updates.listen(
      _onNavigationUpdate,
      onError: (Object _) {
        if (!mounted || !_isNavigating) return;
        setState(() => _navigationGpsFailed = true);
      },
    );
    _followRoute(route);
  }

  /// Segue [route] da capo: ricomincia anche gli annunci vocali.
  void _followRoute(RouteOption route) {
    _voiceGuidance.reset();
    _navigationService.start(route);
  }

  // --- Bussola e mappa orientata ----------------------------------------

  void _onCompassHeading(double raw) {
    final heading = _headingSmoother.add(raw);
    final now = DateTime.now();
    final previous = _deviceHeading;
    // Al massimo dieci aggiornamenti al secondo, e solo se cambia davvero.
    if (previous != null &&
        (now.difference(_lastHeadingUpdate) <
                const Duration(milliseconds: 100) ||
            angleDifference(previous, heading).abs() < 2)) {
      return;
    }
    _lastHeadingUpdate = now;
    if (!mounted) return;
    setState(() => _deviceHeading = heading);
    if (_headingUp && !_isNavigating) _applyMapRotation();
  }

  /// Direzione da tenere in alto: in navigazione quella del percorso (più
  /// stabile della bussola, che risente di ferro e magneti), altrimenti
  /// quella del telefono.
  double? get _upHeading {
    if (_isNavigating) {
      final at =
          _navigationUpdate?.snappedPosition ?? _navigationUpdate?.position;
      final routeHeading = at == null ? null : routeBearingAt(_routePoints, at);
      return routeHeading ?? _deviceHeading;
    }
    return _deviceHeading;
  }

  /// Direzione del cono sul pallino: la bussola o, senza, il verso del
  /// percorso durante la navigazione.
  double? get _coneHeading =>
      _deviceHeading ?? (_isNavigating ? _upHeading : null);

  void _applyMapRotation({LatLng? center, double? zoom}) {
    final up = _headingUp ? _upHeading : null;
    final target = up == null ? 0.0 : -up;
    final turn = angleDifference(_mapRotation, target).abs() >= 3;
    try {
      if (center != null) {
        _mapController.moveAndRotate(
          center,
          zoom ?? _mapController.camera.zoom,
          turn ? target : _mapRotation,
        );
      } else if (turn) {
        _mapController.rotate(target);
      } else {
        return;
      }
      _mapRotation = _mapController.camera.rotation;
    } catch (_) {
      // La mappa non è ancora pronta.
    }
  }

  Future<void> _toggleHeadingUp() async {
    final enable = !_headingUp;
    // Se la bussola risponde già, il permesso c'è.
    if (enable && !_isNavigating && _deviceHeading == null) {
      final allowed = await _compass.requestPermission();
      if (!mounted) return;
      if (!allowed) {
        _showSnack(
          'Il browser non permette di leggere la bussola: la mappa resta '
          'con il nord in alto.',
          icon: Icons.explore_off_outlined,
        );
        return;
      }
      if (_deviceHeading == null) {
        _showSnack(
          'Gira un po\' il telefono: appena la bussola risponde la mappa si '
          'orienta nella tua direzione.',
          icon: Icons.explore_outlined,
        );
      }
    }
    setState(() => _headingUp = enable);
    _applyMapRotation();
    // La rotazione gira intorno al centro: il percorso va rimesso in vista.
    if (_routes.isNotEmpty && !_isNavigating) _fitRoute();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_headingUpKey, enable))
        .catchError((_) => false);
  }

  void _onNavigationUpdate(NavigationUpdate update) {
    if (!mounted || !_isNavigating) return;
    final signalBack = _gpsSignalLost;
    setState(() {
      _navigationGpsFailed = false;
      _navigationUpdate = update;
      _userLocation = update.position;
      _userAccuracy = update.accuracy > 0 ? update.accuracy : null;
      _userFix.remember(
        PositionFix(update.position, update.accuracy, DateTime.now()),
      );
      _gpsSignalLost = false;
      // Arrivati al parcheggio si prosegue in sedia a rotelle.
      final parking = _routes.isEmpty
          ? null
          : _routes[_selectedRouteIndex].parking;
      if (parking != null &&
          haversineDistance(parking.position, update.position) <= 40) {
        _passedParking = true;
      }
      // Le tappe raggiunte non servono più a un eventuale ricalcolo.
      _stops = _stops
          .where((s) => haversineDistance(s.position, update.position) > 30)
          .toList();
    });
    _restartGpsWatchdog();
    // Senza rete si resta allo zoom delle tile salvate per il percorso.
    // Con "direzione in alto" la mappa gira nel verso del percorso.
    _applyMapRotation(
      center: update.position,
      zoom: _isOffline && _offlineRoute.hasSavedRoute
          ? OfflineRouteService.offlineZoom
          : 17.5,
    );
    if (signalBack) {
      _ttsService.speak(
        _voiceLanguage == 'it' ? 'Segnale GPS ritrovato' : 'GPS signal found',
        _voiceLanguage,
      );
    }

    // Gli annunci arrivano a tappe (prosegui, tra 100 metri, ora): prima
    // l'istruzione si ripeteva a ogni aggiornamento del GPS.
    final speech = _voiceGuidance.next(
      update,
      _voiceLanguage,
      brief: _ttsService.guidance == VoiceGuidanceMode.brief,
    );
    if (speech != null) _ttsService.speak(speech, _voiceLanguage);
    if (update.hasArrived) {
      unawaited(_tripResume.clear());
      _maybeAskAboutEntrance();
    }
    // Un avviso alla volta: se è appena stata detta una manovra, l'ostacolo
    // si annuncia al prossimo aggiornamento.
    if (speech == null) _maybeWarnObstacleAhead(update);
    _maybeAskAboutObstacle(update.position);
    if (_tripShare.isSharing) {
      if (update.hasArrived) {
        _tripShare.arrived(update.position);
        unawaited(_tripShare.finishAfterArrival());
        setState(() {});
      } else {
        final remaining = _remaining(update);
        _tripShare.update(
          position: update.position,
          accuracy: update.accuracy,
          remainingMeters: remaining?.$1,
          remainingSeconds: remaining?.$2,
        );
      }
    }

    if (!update.isOffRoute && update.snappedPosition != null) {
      _lastOnRoutePoint = update.snappedPosition;
    }
    // Senza rete il ricalcolo non può riuscire: si segue la linea e si
    // ricalcola quando la rete torna.
    if (update.isOffRoute &&
        !_isRecalculating &&
        !_isOffline &&
        _endPoint != null) {
      final last = _lastRecalculation;
      // Un ricalcolo ogni 10 secondi al massimo: il servizio dei percorsi
      // ha un limite di richieste e il GPS può restare impreciso a lungo.
      if (last == null ||
          DateTime.now().difference(last) >= const Duration(seconds: 10)) {
        _lastRecalculation = DateTime.now();
        _recalculate(update.position, leftAt: _lastOnRoutePoint);
      }
    }
  }

  /// Avvisa a voce di un ostacolo segnalato sul percorso prima di
  /// arrivarci (circa 45 secondi prima, tra 35 e 80 m lungo il tracciato),
  /// una volta per ostacolo.
  void _maybeWarnObstacleAhead(NavigationUpdate update) {
    final tracker = _navigationService.tracker;
    if (tracker == null || update.hasArrived || update.isOffRoute) return;
    final along = tracker.totalLength - update.remainingDistance;
    // Tra due avvisi di ostacoli passano almeno 8 secondi.
    final last = _lastObstacleWarningAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 8)) {
      return;
    }
    final ahead = obstacleAheadToAnnounce(
      tracker,
      along,
      _obstacles,
      _announcedObstacleIds,
      FirebaseAuth.instance.currentUser?.uid,
      maxAhead: aheadWarningDistance(update.speed),
    );
    if (ahead == null) return;
    _announcedObstacleIds.add(ahead.obstacle.id);
    _lastObstacleWarningAt = DateTime.now();
    final spoken = VoiceGuidance.spokenDistance(ahead.distance, _voiceLanguage);
    _ttsService.speak(
      _voiceLanguage == 'it'
          ? 'Attenzione, tra $spoken ostacolo segnalato: ${ahead.obstacle.type}'
          : 'Caution, reported obstacle in $spoken',
      _voiceLanguage,
    );
  }

  /// Come "GPS signal lost" di Google Maps: se la posizione non arriva da
  /// 30 secondi la si chiede direttamente. Il GPS manda aggiornamenti solo
  /// quando ci si sposta, quindi chi è fermo (a un semaforo, all'arrivo) non
  /// deve sentirsi dire che il segnale è perso: l'avviso parte solo se anche
  /// la richiesta diretta fallisce.
  void _restartGpsWatchdog() {
    _gpsWatchdog?.cancel();
    if (_navigationUpdate?.hasArrived ?? false) return;
    _gpsWatchdog = Timer(_gpsSilenceLimit, () async {
      if (!mounted || !_isNavigating || _gpsSignalLost) return;
      final check = await _locationService.getCurrentLocation();
      if (!mounted || !_isNavigating) return;
      if (check.position != null && !check.isApproximate) {
        _restartGpsWatchdog();
        return;
      }
      setState(() => _gpsSignalLost = true);
      _ttsService.speak(
        _voiceLanguage == 'it'
            ? 'Segnale GPS perso. Cerco la posizione.'
            : 'GPS signal lost. Searching.',
        _voiceLanguage,
      );
    });
  }

  /// Ricalcola il percorso da [from]. Con [leftAt], il punto in cui si è
  /// lasciato il percorso, chiede poi se la deviazione era per un ostacolo.
  Future<void> _recalculate(LatLng from, {LatLng? leftAt}) async {
    _isRecalculating = true;
    try {
      final routes = await _getRoutes(
        from,
        _endPoint!,
        _travelMode,
        duringNavigation: true,
      );
      if (mounted &&
          routes.isNotEmpty &&
          routes.first.steps.isNotEmpty &&
          _isNavigating) {
        setState(() {
          _routes = routes;
          _selectedRouteIndex = 0;
          _routePoints = routes.first.points;
        });
        _followRoute(routes.first);
        if (leftAt != null) _maybeAskAboutDeviation(leftAt);
      }
    } catch (_) {
      // Si riprova al prossimo aggiornamento di posizione.
    } finally {
      _isRecalculating = false;
    }
  }

  /// Durante la navigazione lo schermo resta acceso (dove il browser lo
  /// consente).
  void _keepScreenOn(bool enable) {
    unawaited(WakelockPlus.toggle(enable: enable).catchError((Object _) {}));
  }

  /// La rete è caduta o tornata.
  void _onConnectivity(bool online) {
    if (!mounted || _isOffline == !online) return;
    setState(() => _isOffline = !online);
    if (!_isNavigating) {
      _showSnack(
        online
            ? 'Connessione tornata.'
            : 'Sei senza rete: ricerche e nuovi percorsi non sono disponibili.',
        icon: online ? Icons.wifi_rounded : Icons.cloud_off_rounded,
      );
      return;
    }
    _ttsService.speak(
      online
          ? (_voiceLanguage == 'it' ? 'Connessione tornata' : 'Back online')
          : (_voiceLanguage == 'it'
                ? 'Sei senza rete. Continua a seguire il percorso.'
                : 'You are offline. Keep following the route.'),
      _voiceLanguage,
    );
    final update = _navigationUpdate;
    if (online &&
        update != null &&
        update.isOffRoute &&
        !_isRecalculating &&
        _endPoint != null) {
      _recalculate(update.position);
    }
  }

  /// "Salva per l'uso senza rete" nella scheda dei percorsi.
  Future<void> _saveRouteOffline() async {
    final points = _routePoints;
    if (points.isEmpty || _offlineProgress != null) return;
    setState(() => _offlineProgress = (0, 0));
    final result = await _offlineRoute.saveRoute(
      points,
      onProgress: (done, total) {
        if (mounted) setState(() => _offlineProgress = (done, total));
      },
    );
    if (!mounted) return;
    setState(() {
      _offlineProgress = null;
      if (result == OfflineSaveResult.saved ||
          result == OfflineSaveResult.partial) {
        _offlineSavedFor = points;
      }
    });
    final colors = AppColors.of(context);
    switch (result) {
      case OfflineSaveResult.saved:
        _showSnack(
          'Mappa del percorso salvata: se la rete cade resta visibile, e la '
          'navigazione continua.',
          iconColor: colors.success,
          icon: Icons.offline_pin_rounded,
        );
      case OfflineSaveResult.partial:
        _showSnack(
          'Mappa salvata in parte: senza rete potrebbe mancare qualche zona.',
          icon: Icons.offline_pin_outlined,
        );
      case OfflineSaveResult.tooLong:
        _showError(
          'Percorso troppo lungo da salvare: si salvano al massimo pochi '
          'chilometri.',
          Icons.info_outline_rounded,
        );
      case OfflineSaveResult.failed:
        _showError(
          'Non è stato possibile salvare la mappa. Controlla la connessione.',
          Icons.error_outline_rounded,
        );
    }
  }

  /// Metri e secondi che mancano all'arrivo, stimati dall'avanzamento.
  (double, double)? _remaining(NavigationUpdate? update) {
    if (_routes.isEmpty) return null;
    final route = _routes[_selectedRouteIndex.clamp(0, _routes.length - 1)];
    final left = 1 - (update?.progress ?? 0).clamp(0.0, 1.0);
    return (route.distance * left, route.duration * left);
  }

  /// "Condividi il viaggio" durante la navigazione, come "Share trip
  /// progress" di Google Maps.
  Future<void> _shareTrip() async {
    if (_tripShare.isSharing) {
      final action = await showShareTripOptions(context);
      if (!mounted || action == null) return;
      if (action == ShareTripAction.copyLink) {
        await _copyTripLink(_tripShare.activeId!);
      } else {
        await _tripShare.stop();
        if (!mounted) return;
        setState(() {});
        _showSnack(
          'Condivisione interrotta: il link non mostra più la tua posizione.',
          icon: Icons.location_off_outlined,
        );
      }
      return;
    }
    final destination = _endPoint;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (destination == null || userId == null) return;
    final name = _endController.text.isEmpty
        ? 'destinazione'
        : _endController.text;
    if (!await showShareTripConsent(context, name) || !mounted) return;
    final position =
        _navigationUpdate?.position ?? _userLocation ?? _startPoint;
    if (position == null) {
      _showError(
        'Serve la tua posizione per condividere il viaggio.',
        Icons.location_disabled_rounded,
      );
      return;
    }
    final remaining = _remaining(_navigationUpdate);
    try {
      final id = await _tripShare.start(
        userId: userId,
        position: position,
        accuracy: _userAccuracy ?? 0,
        destination: destination,
        destinationName: name,
        remainingMeters: remaining?.$1,
        remainingSeconds: remaining?.$2,
      );
      if (!mounted) return;
      setState(() {});
      await _copyTripLink(id);
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile condividere il viaggio. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _copyTripLink(String id) async {
    final link = TripShareService.linkFor(id, Uri.base).toString();
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      _showSnack(
        'Link copiato: invialo a chi vuoi, per esempio su WhatsApp.',
        iconColor: AppColors.of(context).success,
        icon: Icons.check_circle_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Link del viaggio: $link', icon: Icons.link_rounded);
    }
  }

  void _stopNavigation() {
    _keepScreenOn(false);
    if (_tripShare.isSharing) unawaited(_tripShare.stop());
    unawaited(_tripResume.clear());
    _gpsWatchdog?.cancel();
    _gpsSignalLost = false;
    _ttsService.stop();
    _ttsService.reset();
    _navigationSubscription?.cancel();
    _navigationSubscription = null;
    _navigationService.stop();
    _verifyTimer?.cancel();
    setState(() {
      _isNavigating = false;
      _navigationUpdate = null;
      _navigationFirstStep = null;
      _verifyPrompt = null;
      _passPrompt = null;
      _closeDeviationPromptInState();
      _clearRouteAlert();
    });
    // Senza navigazione la mappa segue la bussola o torna con il nord in
    // alto.
    _applyMapRotation();
    _fitRoute();
  }

  // --- Posizione -----------------------------------------------------------

  Future<void> _locateUser({bool showErrors = false}) async {
    setState(() => _isLocatingUser = true);
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocatingUser = false);
    final position = result.position;
    if (position != null &&
        !_userFix.accept(
          PositionFix(position, result.accuracy ?? 0, DateTime.now()),
        )) {
      // Resta la posizione precedente, più precisa e ancora recente.
      final kept = _userLocation;
      if (kept != null) _mapController.move(kept, 16);
      return;
    }
    if (position != null) {
      setState(() {
        _userLocation = _center = position;
        _userAccuracy = result.accuracy;
      });
      _mapController.move(_center, 16);
      if (showErrors && result.isApproximate) {
        _showError(
          'Posizione approssimativa, stimata dalla rete. Il cerchio azzurro '
          'mostra dove potresti essere.',
          Icons.gps_not_fixed_rounded,
        );
      }
    } else if (showErrors) {
      _showError(
        result.error ?? 'Posizione non disponibile',
        Icons.location_disabled_rounded,
      );
    }
  }

  /// "La tua posizione" come partenza o arrivo, come in Google Maps.
  Future<void> _useMyLocation({required bool isStart}) async {
    _geocodingService.cancelSearch();
    FocusScope.of(context).unfocus();
    final known = _userLocation;
    if (known != null) {
      setState(() => _setPoint(isStart, known, 'La tua posizione'));
    } else {
      setState(() => isStart ? _isLocatingStart = true : _isLocatingEnd = true);
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(
        () => isStart ? _isLocatingStart = false : _isLocatingEnd = false,
      );
      final position = result.position;
      if (position == null) {
        _showError(
          result.error ?? 'Posizione non disponibile',
          Icons.location_disabled_rounded,
        );
        return;
      }
      setState(() {
        _center = _userLocation = position;
        _userAccuracy = result.accuracy;
        _setPoint(isStart, position, 'La tua posizione');
      });
      if (result.isApproximate) {
        _showError(
          'Posizione rilevata dalla rete. Per il GPS preciso consenti la '
          'posizione dal lucchetto nella barra del browser.',
          Icons.gps_not_fixed_rounded,
        );
      }
    }
    if (_startPoint != null && _endPoint != null) {
      _calculateRoute();
    } else {
      (isStart ? _endFocus : _startFocus).requestFocus();
    }
  }

  // --- Ostacoli ------------------------------------------------------------

  /// Intervalli minimi imposti anche dalle regole di Firestore.
  static const Duration _reportInterval = Duration(seconds: 30);
  static const Duration _removalInterval = Duration(seconds: 10);
  DateTime? _lastReportAt;
  DateTime? _lastRemovalAt;

  /// Secondi da attendere prima della prossima azione, o `null` se si può.
  int? _secondsToWait(DateTime? last, Duration interval) {
    if (last == null) return null;
    final left = interval - DateTime.now().difference(last);
    return left > Duration.zero ? left.inSeconds + 1 : null;
  }

  /// Segnala un ostacolo in [point]. Con [preset] (per esempio un tipo
  /// detto a voce) non si apre la scheda per sceglierlo.
  Future<void> _reportObstacle(LatLng point, {ReportDraft? preset}) async {
    final wait = _secondsToWait(_lastReportAt, _reportInterval);
    if (wait != null) {
      _showError(
        'Puoi fare una segnalazione ogni 30 secondi: riprova tra $wait s.',
        Icons.hourglass_bottom_rounded,
      );
      return;
    }
    final draft = preset ?? await showReportObstacleSheet(context);
    if (draft == null || !mounted) return;
    final type = draft.type;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final duplicate = findDuplicate(_obstacles, point, type);
    if (duplicate != null) {
      final canConfirm = duplicate.canBeConfirmedBy(userId);
      final choice = await showDuplicateDialog(
        context,
        duplicate,
        haversineDistance(duplicate.position, point),
        canConfirm: canConfirm,
      );
      if (choice == null || !mounted) return;
      if (choice == DuplicateChoice.confirmExisting) {
        await _confirmObstacle(duplicate, userId);
        return;
      }
    }

    final before = _myContributions();
    bool photoSaved;
    try {
      photoSaved = await _obstacleService.add(
        point,
        type,
        userId,
        photo: draft.photo,
      );
      _lastReportAt = DateTime.now();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(
        error.code == 'permission-denied'
            ? 'Hai appena fatto una segnalazione: riprova tra qualche secondo.'
            : 'Non è stato possibile salvare la segnalazione. Riprova.',
        Icons.error_outline_rounded,
      );
      return;
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile salvare la segnalazione. Riprova.',
        Icons.error_outline_rounded,
      );
      return;
    }
    if (!mounted) return;
    if (!photoSaved) {
      _showThanks(
        'Ostacolo segnalato, ma la foto non è stata salvata. Grazie per il '
        'contributo!',
        before,
        iconColor: AppColors.of(context).warning,
        icon: Icons.no_photography_outlined,
      );
      return;
    }
    _showThanks('Ostacolo segnalato. Grazie per il contributo!', before);
  }

  /// Segnala un ostacolo nella posizione dell'utente o, se non è nota, al
  /// centro della mappa. Alternativa alla pressione prolungata, più comoda da
  /// tastiera, con un lettore di schermo o con difficoltà motorie.
  Future<void> _reportHere() async {
    final location = _userLocation;
    final point = location ?? _mapController.camera.center;
    if (location == null) {
      _showSnack(
        'Posizione non disponibile: la segnalazione andrà al centro della mappa.',
        iconColor: AppColors.of(context).info,
        icon: Icons.info_outline_rounded,
      );
    }
    await _reportObstacle(point);
  }

  /// Filtri di accessibilità della ricerca: cerca su OpenStreetMap nella
  /// zona inquadrata dalla mappa. Con `null` il filtro si toglie.
  Future<void> _searchNearby(NearbyFilter? filter) async {
    final request = ++_nearbyRequest;
    if (filter == null) {
      setState(() => _nearby = const NearbySearch());
      return;
    }
    setState(() => _nearby = NearbySearch(filter: filter, isLoading: true));
    final results = await _nearbyService.search(
      filter,
      _mapController.camera.center,
    );
    if (!mounted || request != _nearbyRequest) return;
    setState(() => _nearby = NearbySearch(filter: filter, results: results));
  }

  /// "Segnala a voce": si dice il tipo di ostacolo ("gradino", "auto sul
  /// marciapiede") e l'app chiede conferma prima di salvarlo nella
  /// posizione in cui ci si trovava quando si è parlato.
  Future<void> _reportByVoice() async {
    if (_isListening) {
      _speechInput.cancel();
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) return;
    final point = _userLocation ?? _mapController.camera.center;
    _ttsService.stop();
    setState(() {
      _isListening = true;
      _voiceReport = null;
    });
    _showSnack(
      _voiceLanguage == 'it'
          ? 'Ti ascolto: di\' il tipo di ostacolo, per esempio «gradino» o '
                '«auto sul marciapiede».'
          : 'Listening: say the obstacle, for example "step" or "parked car".',
      iconColor: AppColors.of(context).info,
      icon: Icons.mic_rounded,
    );
    final heard = await _speechInput.listen(_voiceLanguage);
    if (!mounted) return;
    setState(() => _isListening = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    for (final text in heard) {
      final type = matchObstacleType(text);
      if (type != null) {
        setState(() => _voiceReport = (point: point, heard: text, type: type));
        return;
      }
    }
    if (heard.isEmpty) {
      _showError(
        'Non ho sentito nulla. Controlla che il microfono sia consentito e '
        'riprova.',
        Icons.mic_off_rounded,
      );
      return;
    }
    _showError(
      'Non ho riconosciuto il tipo di ostacolo in «${heard.first}». '
      "Sceglilo dall'elenco.",
      Icons.help_outline_rounded,
    );
    await _reportObstacle(point);
  }

  Future<void> _confirmVoiceReport({required bool fromList}) async {
    final report = _voiceReport;
    setState(() => _voiceReport = null);
    if (report == null) return;
    await _reportObstacle(
      report.point,
      preset: fromList ? null : ReportDraft(report.type),
    );
  }

  Future<void> _confirmObstacle(Obstacle obstacle, String userId) async {
    final before = _myContributions();
    try {
      await _obstacleService.confirm(obstacle.id, userId);
      await _logHelp(userId, HelpKind.confirm, obstacle);
      if (!mounted) return;
      _showThanks("Grazie! Hai confermato che l'ostacolo c'è ancora.", before);
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile registrare la conferma. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  /// I propri contributi come li vede la scheda "Le tue segnalazioni".
  Contributions? _myContributions() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    return userId == null ? null : Contributions.of(_allObstacles, userId);
  }

  Future<void> _logHelp(String userId, HelpKind kind, Obstacle obstacle) =>
      _contributionLog.add(
        userId,
        HelpEntry(kind, obstacle.id, DateTime.now()),
      );

  /// Ringrazia per un contributo dicendo i punti guadagnati e quanti ne
  /// mancano al livello dopo, o il nuovo livello o badge, con "Vedi" per
  /// aprire "Le tue segnalazioni". [before] sono i contributi di prima:
  /// Firestore aggiorna subito le segnalazioni lette con la scrittura
  /// appena fatta, quindi quelli di adesso la contano già.
  void _showThanks(
    String message,
    Contributions? before, {
    Color? iconColor,
    IconData? icon,
  }) {
    final after = _myContributions();
    final reward = before == null || after == null
        ? null
        : ContributionReward.between(before, after);
    final extra = reward?.message ?? '';
    _showSnack(
      extra.isEmpty ? message : '$message $extra',
      iconColor: iconColor ?? AppColors.of(context).success,
      icon:
          icon ??
          (reward?.isMilestone ?? false
              ? Icons.emoji_events_rounded
              : Icons.check_circle_rounded),
      action: extra.isEmpty
          ? null
          : SnackBarAction(
              label: 'Vedi',
              textColor: AppPalette.accent,
              onPressed: _openContributions,
            ),
    );
  }

  /// Un ostacolo entro 1 km da te che nessuno conferma da 30 giorni.
  VerifySuggestion? _verifySuggestion(String userId) {
    final location = _userLocation;
    if (location == null) return null;
    return findVerifySuggestion(
      _obstacles,
      userId,
      DateTime.now(),
      (o) => haversineDistance(location, o.position),
    );
  }

  /// All'apertura, una volta a settimana, "La tua settimana" con i
  /// contributi della settimana prima, se ce ne sono stati.
  Future<void> _maybeShowWeeklyReview() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (_weeklyReviewChecked ||
        userId == null ||
        !_obstaclesLoaded ||
        !_contributionLogLoaded) {
      return;
    }
    _weeklyReviewChecked = true;
    final week = DateRange.previousWeek(DateTime.now());
    final contributions = Contributions.of(_allObstacles, userId);
    final review = WeeklyReview.of(
      contributions,
      _contributionLog.helps,
      week,
      userId,
    );
    if (review.isEmpty) return;
    if (await _contributionLog.wasWeekShown(userId, week)) return;
    if (!mounted || _isNavigating) return;
    await _contributionLog.markWeekShown(userId, week);
    if (!mounted) return;
    final suggestion = _verifySuggestion(userId);
    final action = await showWeeklyReviewSheet(
      context,
      review: review,
      contributions: contributions,
      suggestion: suggestion,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case WeeklyReviewAction.contribute:
        await _reportHere();
      case WeeklyReviewAction.verify:
        if (suggestion == null) return;
        _mapController.move(suggestion.obstacle.position, 18);
        await _openObstacle(suggestion.obstacle);
      case WeeklyReviewAction.showAll:
        await _openContributions();
    }
  }

  /// "Le tue segnalazioni": toccandone una la mappa la mostra.
  Future<void> _openContributions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final picked = await showContributionsSheet(
      context,
      Contributions.of(_allObstacles, userId),
      suggestion: _verifySuggestion(userId),
    );
    if (picked == null || !mounted) return;
    _mapController.move(picked.position, 18);
    if (_obstacles.any((o) => o.id == picked.id)) {
      await _openObstacle(picked);
    } else {
      _showSnack(
        'Questa segnalazione non è più sulla mappa: '
        '${ReportStatus.of(picked, DateTime.now()).label.toLowerCase()}.',
        icon: Icons.visibility_off_outlined,
      );
    }
  }

  Future<void> _openObstacle(Obstacle obstacle) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final action = await showObstacleDetailsSheet(
      context,
      obstacle,
      currentUserId: userId,
      loadPhoto: _obstacleService.loadPhoto,
    );
    if (action == null || !mounted) return;
    if (action == ObstacleAction.confirm) {
      if (userId != null) await _confirmObstacle(obstacle, userId);
      return;
    }
    if (action == ObstacleAction.thank) {
      if (userId != null) await _thankReporter(obstacle, userId);
      return;
    }
    final vote = action.passVote;
    if (vote != null) {
      if (userId != null) await _votePass(obstacle, userId, vote);
      return;
    }
    if (userId == null) return;
    await _removeObstacle(obstacle, userId);
  }

  /// Un ospite può togliere solo le proprie segnalazioni (regole Firestore).
  bool _canRemove(Obstacle obstacle, String? userId) {
    if (userId == null) return false;
    final user = FirebaseAuth.instance.currentUser;
    return !(user?.isAnonymous ?? false) || obstacle.isReportedBy(userId);
  }

  Future<void> _removeObstacle(Obstacle obstacle, String userId) async {
    // Un ospite non può cancellare le segnalazioni altrui: il suo "non c'è
    // più" diventa un voto, e con due voti l'ostacolo sparisce.
    if (!_canRemove(obstacle, userId)) {
      await _voteNotThere(obstacle, userId);
      return;
    }
    final wait = _secondsToWait(_lastRemovalAt, _removalInterval);
    if (wait != null) {
      _showError(
        'Puoi rimuovere una segnalazione ogni 10 secondi: riprova tra $wait s.',
        Icons.hourglass_bottom_rounded,
      );
      return;
    }
    try {
      await _obstacleService.remove(
        obstacle.id,
        userId,
        hasPhoto: obstacle.hasPhoto,
      );
      _lastRemovalAt = DateTime.now();
      if (!obstacle.isReportedBy(userId)) {
        await _logHelp(userId, HelpKind.gone, obstacle);
      }
      if (!mounted) return;
      _showSnack(
        'Ostacolo rimosso dalla mappa.',
        iconColor: AppColors.of(context).success,
        icon: Icons.check_circle_rounded,
      );
      // Durante la navigazione il percorso resta quello in corso.
      if (!_isNavigating && _startPoint != null && _endPoint != null) {
        _calculateRoute();
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(
        error.code == 'permission-denied'
            ? 'Hai appena rimosso una segnalazione: riprova tra qualche secondo.'
            : "Non è stato possibile rimuovere l'ostacolo.",
        Icons.error_outline_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        "Non è stato possibile rimuovere l'ostacolo.",
        Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _voteNotThere(Obstacle obstacle, String userId) async {
    if (!obstacle.canVoteNotThereBy(userId)) {
      _showSnack(
        "Hai già detto che questo ostacolo non c'è più. Grazie!",
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    try {
      await _obstacleService.voteNotThere(obstacle.id, userId);
      await _logHelp(userId, HelpKind.gone, obstacle);
      if (!mounted) return;
      final hides =
          obstacle.notThereBy.length + 1 >= Obstacle.notThereVotesToHide;
      _showSnack(
        hides
            ? "Grazie! Anche altri l'avevano segnalato: l'ostacolo è stato "
                  'tolto dalla mappa.'
            : 'Grazie! Se anche un\'altra persona lo conferma, l\'ostacolo '
                  'sparisce dalla mappa.',
        iconColor: AppColors.of(context).success,
        icon: Icons.check_circle_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile registrare la risposta. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  // --- Domande e avvisi durante la navigazione ------------------------------

  /// Come Google Maps chiede "Is construction still there?", passando vicino
  /// a un ostacolo segnalato si chiede se c'è ancora.
  void _maybeAskAboutObstacle(LatLng position) {
    final current = _verifyPrompt;
    if (current != null) {
      // Ostacolo superato da un pezzo: la domanda non serve più.
      if (haversineDistance(position, current.position) >
          kVerifyDismissRadius) {
        _closeVerifyPrompt();
      }
      return;
    }
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final obstacle = obstacleToVerify(
      position,
      _obstacles,
      _askedObstacleIds,
      userId,
    );
    if (obstacle == null) return;
    _askedObstacleIds.add(obstacle.id);
    setState(() => _verifyPrompt = obstacle);
    _ttsService.speak(
      _voiceLanguage == 'it'
          ? (obstacle.isOutOfService
                ? "È ancora fuori servizio? ${obstacle.type}"
                : "C'è ancora questo ostacolo? ${obstacle.type}")
          : (obstacle.isOutOfService
                ? 'Is the lift or ramp still out of service?'
                : 'Is this obstacle still there?'),
      _voiceLanguage,
    );
    // Senza risposta la domanda sparisce da sola.
    _verifyTimer?.cancel();
    _verifyTimer = Timer(const Duration(seconds: 45), _closeVerifyPrompt);
  }

  /// All'arrivo chiede com'era l'ingresso, una volta per viaggio e non
  /// più di qualche volta al giorno (vedi [ArrivalQuestionPolicy]).
  Future<void> _maybeAskAboutEntrance() async {
    if (_arrivalHandled) return;
    _arrivalHandled = true;
    final destination = _endPoint;
    if (destination == null || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    if (!await _arrivalPolicy.tryAsk() || !mounted) return;
    setState(() => _arrivalPrompt = destination);
    // Prima si lascia finire l'annuncio dell'arrivo.
    Timer(const Duration(seconds: 4), () {
      if (!mounted || _arrivalPrompt == null || _voiceLanguage != 'it') return;
      _ttsService.speak("Com'era l'ingresso?", _voiceLanguage);
    });
    _arrivalTimer?.cancel();
    _arrivalTimer = Timer(const Duration(seconds: 60), _closeArrivalPrompt);
  }

  /// Dopo un ricalcolo per uscita dal percorso chiede se si è cambiata
  /// strada per un ostacolo, una volta per viaggio e solo se lì vicino non
  /// c'è già una segnalazione.
  void _maybeAskAboutDeviation(LatLng leftAt) {
    if (_deviationAsked ||
        FirebaseAuth.instance.currentUser == null ||
        !shouldAskAboutDeviation(leftAt, _obstacles)) {
      return;
    }
    _deviationAsked = true;
    setState(() => _deviationPrompt = leftAt);
    _ttsService.speak(
      _voiceLanguage == 'it'
          ? 'Hai cambiato strada per un ostacolo?'
          : 'Did you change route because of an obstacle?',
      _voiceLanguage,
    );
    _deviationTimer?.cancel();
    _deviationTimer = Timer(const Duration(seconds: 45), _closeDeviationPrompt);
  }

  /// Da chiamare dentro setState.
  void _closeDeviationPromptInState() {
    _deviationTimer?.cancel();
    _deviationPrompt = null;
  }

  void _closeDeviationPrompt() {
    if (mounted && _deviationPrompt != null) {
      setState(_closeDeviationPromptInState);
    }
  }

  Future<void> _reportDeviation() async {
    final point = _deviationPrompt;
    _closeDeviationPrompt();
    if (point != null) await _reportObstacle(point);
  }

  /// Da chiamare dentro setState.
  void _closeArrivalPromptInState() {
    _arrivalTimer?.cancel();
    _arrivalPrompt = null;
  }

  void _closeArrivalPrompt() {
    if (mounted && _arrivalPrompt != null) {
      setState(_closeArrivalPromptInState);
    }
  }

  Future<void> _answerArrivalPrompt(EntranceAnswer answer) async {
    final destination = _arrivalPrompt;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _closeArrivalPrompt();
    if (destination == null || userId == null) return;
    try {
      await _entranceService.add(destination, answer, userId);
      if (!mounted) return;
      _showSnack(
        "Grazie! La tua risposta aiuta chi andrà lì dopo di te.",
        iconColor: AppColors.of(context).success,
        icon: Icons.check_circle_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile salvare la risposta. Riprova più tardi.',
        Icons.error_outline_rounded,
      );
    }
  }

  void _closePassPrompt() {
    if (mounted && _passPrompt != null) setState(() => _passPrompt = null);
  }

  Future<void> _answerPassPrompt(PassVote vote) async {
    final obstacle = _passPrompt;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _closePassPrompt();
    if (obstacle != null && userId != null) {
      await _votePass(obstacle, userId, vote);
    }
  }

  Future<void> _thankReporter(Obstacle obstacle, String userId) async {
    try {
      await _obstacleService.thank(obstacle.id, userId);
      if (!mounted) return;
      _showSnack(
        'Grazie inviato a chi ha segnalato questo ostacolo.',
        iconColor: AppColors.of(context).success,
        icon: Icons.favorite_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile inviare il grazie. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  /// Se le proprie segnalazioni hanno ricevuto nuovi grazie, lo dice.
  Future<void> _announceNewThanks(List<Obstacle> obstacles) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final fresh = await _thanksNotifier.newThanks(
      userId,
      thanksReceived(obstacles, userId),
    );
    if (fresh == 0 || !mounted) return;
    _showSnack(
      fresh == 1
          ? 'Una persona ti ha ringraziato per una tua segnalazione.'
          : '$fresh persone ti hanno ringraziato per le tue segnalazioni.',
      iconColor: AppColors.of(context).success,
      icon: Icons.favorite_rounded,
    );
  }

  Future<void> _votePass(
    Obstacle obstacle,
    String userId,
    PassVote vote,
  ) async {
    final before = _myContributions();
    try {
      await _obstacleService.votePass(obstacle.id, userId, vote);
      await _logHelp(userId, HelpKind.pass, obstacle);
      if (!mounted) return;
      _showThanks(
        'Grazie! La tua risposta aiuta a scegliere i percorsi.',
        before,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile salvare la risposta. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  void _closeVerifyPrompt() {
    _verifyTimer?.cancel();
    if (mounted && _verifyPrompt != null) setState(() => _verifyPrompt = null);
  }

  Future<void> _answerVerifyPrompt({required bool stillThere}) async {
    final obstacle = _verifyPrompt;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _closeVerifyPrompt();
    if (obstacle == null || userId == null) return;
    if (stillThere) {
      await _confirmObstacle(obstacle, userId);
      // Poi una domanda di dettaglio, se non ha già risposto.
      if (mounted && _isNavigating && obstacle.canVotePassBy(userId)) {
        setState(() => _passPrompt = obstacle);
        _verifyTimer?.cancel();
        _verifyTimer = Timer(const Duration(seconds: 45), _closePassPrompt);
      }
    } else {
      await _removeObstacle(obstacle, userId);
    }
  }

  /// Un ostacolo appena segnalato sul tratto ancora da fare: si avvisa e si
  /// cerca un percorso che lo eviti ("Rerouting to avoid road closure").
  Future<void> _checkNewObstaclesOnRoute(List<Obstacle> active) async {
    if (!_isNavigating || _routes.isEmpty || _endPoint == null) {
      return;
    }
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final fresh = active
        .where((o) => !_knownObstacleIds.contains(o.id))
        // Le proprie segnalazioni non sono una sorpresa.
        .where((o) => !o.isReportedBy(userId))
        .toList();
    _knownObstacleIds.addAll(active.map((o) => o.id));
    if (fresh.isEmpty || _routeAlertObstacle != null) return;

    final position = _navigationUpdate?.position ?? _userLocation;
    if (position == null) return;
    final route = _routes[_selectedRouteIndex];
    final blocking = obstaclesAhead(route.points, position, fresh);
    if (blocking.isEmpty) return;

    final obstacle = blocking.first;
    setState(() {
      _routeAlertObstacle = obstacle;
      _routeAlertSearching = true;
      _routeAlertRoutes = null;
    });
    _ttsService.speak(
      _voiceLanguage == 'it'
          ? 'Attenzione: nuovo ostacolo sul percorso. ${obstacle.type}'
          : 'Warning: new obstacle on your route.',
      _voiceLanguage,
    );

    List<RouteOption> routes = const [];
    try {
      routes = await _getRoutes(
        position,
        _endPoint!,
        _travelMode,
        duringNavigation: true,
      );
    } catch (_) {
      routes = const [];
    }
    if (!mounted || !_isNavigating || _routeAlertObstacle != obstacle) return;
    final avoiding = routes
        .where((r) => r.steps.isNotEmpty)
        .where((r) => !blocking.any((o) => routePassesNear(r.points, o)))
        .toList();
    final remaining = route.duration * (1 - (_navigationUpdate?.progress ?? 0));
    setState(() {
      _routeAlertSearching = false;
      _routeAlertRoutes = avoiding.isEmpty ? null : avoiding;
      _routeAlertExtraMinutes = avoiding.isEmpty
          ? 0
          : ((avoiding.first.duration - remaining) / 60).round();
    });
  }

  void _clearRouteAlert() {
    _routeAlertObstacle = null;
    _routeAlertRoutes = null;
    _routeAlertSearching = false;
    _routeAlertExtraMinutes = 0;
  }

  void _useAlternativeRoute() {
    final routes = _routeAlertRoutes;
    if (routes == null || routes.isEmpty) return;
    setState(() {
      _routes = routes;
      _selectedRouteIndex = 0;
      _routePoints = routes.first.points;
      _clearRouteAlert();
    });
    _followRoute(routes.first);
    _ttsService.speak(
      _voiceLanguage == 'it' ? 'Nuovo percorso' : 'New route',
      _voiceLanguage,
    );
  }

  // --- Zoom ----------------------------------------------------------------

  static const double _minZoom = 3;
  static const double _maxZoom = 19;

  void _zoomIn() {
    _zoom = (_zoom + 1).clamp(_minZoom, _maxZoom).toDouble();
    _mapController.move(_center, _zoom);
  }

  void _zoomOut() {
    _zoom = (_zoom - 1).clamp(_minZoom, _maxZoom).toDouble();
    _mapController.move(_center, _zoom);
  }

  int get _selectedRouteWarningCount => _selectedRouteIndex < _routes.length
      ? _routes[_selectedRouteIndex].warnings.length
      : 0;

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasRoutes = _routes.isNotEmpty;
    final choosing = _choosingOnMapFor;
    final showPlaceSheet =
        _stage == SearchPhase.place &&
        _selectedPlace != null &&
        _endPoint != null &&
        !hasRoutes &&
        !_isNavigating &&
        choosing == null;
    final searchFocused = _startFocus.hasFocus || _endFocus.hasFocus;
    final double controlsBottom = _isNavigating
        ? 32
        : choosing != null
        ? 96
        : hasRoutes
        ? _routeSheetHeight
        : showPlaceSheet
        ? 196 +
              22.0 *
                  (_isLoadingAccessibility
                      ? 1
                      : AccessibilityFacts.rowCount(_placeAccessibility))
        : (_showReportHint ? 80 : 32);

    final children = <Widget>[
      _buildMap(context),
      const Positioned(left: 12, bottom: 4, child: OsmAttribution()),
    ];

    if (choosing != null) {
      children.addAll(_buildChooseOnMap(choosing));
    } else if (!_isNavigating) {
      final Widget search = _isSearchExpanded
          ? SearchPanel(
              key: ValueKey('search-${_stage.name}'),
              stage: _stage,
              startController: _startController,
              endController: _endController,
              startFocus: _startFocus,
              endFocus: _endFocus,
              startItems: _startItems,
              endItems: _endItems,
              recentPlaces: _recents,
              home: _savedPlaces.home,
              work: _savedPlaces.work,
              savedPlaces: [
                for (final saved in _saved)
                  if (saved.kind == SavedKind.other) saved,
              ],
              onSavedShortcut: _openSavedShortcut,
              onRemoveSaved: _removeSaved,
              noResultsForStart: _noResultsStart,
              noResultsForEnd: _noResultsEnd,
              userLocation: _userLocation,
              isLocatingStart: _isLocatingStart,
              isLocatingEnd: _isLocatingEnd,
              isCalculating: _isCalculating,
              canCalculate:
                  _startPoint != null && _endPoint != null && !hasRoutes,
              hasStartPoint: _startPoint != null,
              hasEndPoint: _endPoint != null,
              travelMode: _travelMode,
              onStartChanged: (q) => _onSearchChanged(q, true),
              onEndChanged: (q) => _onSearchChanged(q, false),
              onSubmitted: _onSubmitted,
              onSelectSuggestion: _selectSuggestion,
              onRemoveRecent: _removeRecent,
              onUseMyLocation: _useMyLocation,
              onChooseOnMap: _chooseOnMap,
              onPaste: _pasteAddress,
              nearby: _nearby,
              onNearbyFilter: _searchNearby,
              onClear: _clearPoint,
              onSwap: _swapPoints,
              onCalculate: _calculateRoute,
              onTravelModeChanged: _setTravelMode,
              onOpenDirections: _openDirections,
              onCloseDirections: _closeDirections,
              onClosePlace: _closePlace,
            )
          : Column(
              key: const ValueKey('search-collapsed'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CollapsedSearchBar(
                  startText: _startController.text,
                  endText: _endController.text,
                  travelMode: _travelMode,
                  onTap: () => setState(() => _isSearchExpanded = true),
                ),
                // Come in Google Maps il mezzo si cambia anche con i
                // percorsi già sullo schermo.
                if (hasRoutes || _isCalculating)
                  TravelModeBar(
                    selected: _travelMode,
                    onSelected: _setTravelMode,
                    padding: const EdgeInsets.only(top: 8),
                  ),
              ],
            );

      children.add(
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TopBar(
                      onLogout: () => FirebaseAuth.instance.signOut(),
                      onOpenContributions: _openContributions,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Sugli schermi larghi il pannello resta stretto e a sinistra,
                // come la casella di ricerca di Google Maps.
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kSearchPanelMaxWidth,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: search,
                      ),
                    ),
                  ),
                ),
                // Mentre si cerca, i filtri non coprono i suggerimenti.
                if (!searchFocused) ...[
                  const SizedBox(height: 12),
                  CategoryFilterBar(
                    categories: _categories,
                    selected: _selectedCategory,
                    countFor: _countForCategory,
                    onSelected: (category) =>
                        setState(() => _selectedCategory = category),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_isNavigating) {
      children.add(
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: NavigationPanel(
            update: _navigationUpdate,
            firstStep: _navigationFirstStep!,
            gpsFailed: _navigationGpsFailed,
            signalLost: _gpsSignalLost,
            language: _voiceLanguage,
            isMuted: _ttsService.muted,
            onStop: _stopNavigation,
            onToggleMute: () => setState(() {
              _ttsService.muted = !_ttsService.muted;
              if (_ttsService.muted) _ttsService.stop();
            }),
            onLanguageChanged: (language) =>
                setState(() => _voiceLanguage = language),
            onOpenVoiceSettings: () => showVoiceSettingsSheet(
              context,
              tts: _ttsService,
              language: _voiceLanguage,
              onLanguageChanged: (language) =>
                  setState(() => _voiceLanguage = language),
              onMutedChanged: (_) => setState(() {}),
            ),
            onRepeat: _ttsService.repeat,
            onShareTrip: _shareTrip,
            isSharingTrip: _tripShare.isSharing,
            isOffline: _isOffline,
            remainingSeconds: _remaining(_navigationUpdate)?.$2,
          ),
        ),
      );
    }

    if (_isNavigating || _arrivalPrompt != null || _voiceReport != null) {
      final alertObstacle = _isNavigating ? _routeAlertObstacle : null;
      final voiceReport = _voiceReport;
      final verify = _isNavigating ? _verifyPrompt : null;
      final deviation = _isNavigating ? _deviationPrompt : null;
      final pass = _isNavigating ? _passPrompt : null;
      final Widget? prompt = voiceReport != null
          ? VoiceReportCard(
              heard: voiceReport.heard,
              type: voiceReport.type,
              onConfirm: () => _confirmVoiceReport(fromList: false),
              onChooseFromList: () => _confirmVoiceReport(fromList: true),
              onCancel: () => setState(() => _voiceReport = null),
            )
          : _arrivalPrompt != null
          ? ArrivalEntranceCard(
              onAnswer: _answerArrivalPrompt,
              onSkip: _closeArrivalPrompt,
            )
          : alertObstacle != null
          ? RouteAlertCard(
              obstacle: alertObstacle,
              isSearching: _routeAlertSearching,
              hasAlternative: _routeAlertRoutes != null,
              extraMinutes: _routeAlertExtraMinutes,
              onUseAlternative: _useAlternativeRoute,
              onKeepRoute: () => setState(_clearRouteAlert),
            )
          : verify != null
          ? ObstacleVerifyCard(
              obstacle: verify,
              // Chi non può rimuovere vota: "Non c'è più" c'è sempre.
              canRemove: true,
              onStillThere: () => _answerVerifyPrompt(stillThere: true),
              onGone: () => _answerVerifyPrompt(stillThere: false),
              onSkip: _closeVerifyPrompt,
            )
          : pass != null
          ? PassabilityCard(
              obstacle: pass,
              onVote: _answerPassPrompt,
              onSkip: _closePassPrompt,
            )
          : deviation != null
          ? DeviationObstacleCard(
              onReport: _reportDeviation,
              onDismiss: _closeDeviationPrompt,
            )
          : null;
      if (prompt != null) {
        children.add(
          Positioned(
            left: 12,
            right: 64,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: prompt,
                ),
              ),
            ),
          ),
        );
      }
    }

    children.add(
      AnimatedPositioned(
        right: 12,
        bottom: controlsBottom,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: MapControls(
          // Il pulsante della bussola compare quando serve: in navigazione,
          // con la bussola che risponde o con la mappa già ruotata.
          compass:
              choosing == null &&
                  (_isNavigating || _deviceHeading != null || _headingUp)
              ? CompassButton(
                  mapRotation: _mapRotation,
                  headingUp: _headingUp,
                  onPressed: _toggleHeadingUp,
                )
              : null,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onLocate: () => _locateUser(showErrors: true),
          isLocating: _isLocatingUser,
          onReport: _isNavigating || choosing != null ? null : _reportHere,
          onToggleParking: choosing != null ? null : _toggleParkingLayer,
          showsParking: _showParkingLayer,
          isLoadingParking: _isLoadingParkings,
          // A voce si segnala anche durante la navigazione, senza mani.
          onVoiceReport:
              _speechInput.isSupported &&
                  choosing == null &&
                  FirebaseAuth.instance.currentUser != null
              ? _reportByVoice
              : null,
          isListening: _isListening,
        ),
      ),
    );

    final pendingTrip = _pendingTrip;
    final showTripCard =
        pendingTrip != null &&
        !hasRoutes &&
        !_isNavigating &&
        !showPlaceSheet &&
        choosing == null;
    if (showTripCard) {
      children.add(
        Positioned(
          left: 12,
          right: 64,
          bottom: 24,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ResumeTripCard(
                  destination: pendingTrip.label,
                  onResume: _resumeTrip,
                  onDismiss: _dismissTrip,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!hasRoutes &&
        !_isNavigating &&
        !showPlaceSheet &&
        !showTripCard &&
        choosing == null &&
        _showReportHint) {
      children.add(
        Positioned(
          left: 12,
          right: 60,
          bottom: 24,
          // Allineato a sinistra: la pillola è larga quanto il suo testo
          // invece di occupare tutta la larghezza dello schermo.
          child: Align(
            alignment: Alignment.bottomLeft,
            child: ReportHint(
              onClose: () => setState(() => _showReportHint = false),
            ),
          ),
        ),
      );
    }

    if (showPlaceSheet) {
      final place = _selectedPlace!;
      final label = formatPlace(place);
      final location = _userLocation;
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PlaceSheet(
                title: label.title,
                subtitle: label.subtitle,
                distanceText: location == null
                    ? null
                    : 'a ${formatDistance(haversineDistance(location, _endPoint!))} da te',
                nearbyObstacles: _obstaclesNear(_endPoint!),
                accessibility: _placeAccessibility,
                isLoadingAccessibility: _isLoadingAccessibility,
                entranceSummary: _entranceSummary,
                onDirections: _openDirections,
                onStart: _startFromPlace,
                onShare: _sharePlace,
                onClose: _closePlace,
                onSave: _savePlace,
                savedLabels: [
                  for (final saved in _savedPlaces.savedAs(place)) saved.label,
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (hasRoutes && !_isNavigating && choosing == null) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RouteOptionsSheet(
            routes: _routes,
            selectedIndex: _selectedRouteIndex,
            onSelect: _selectRoute,
            onStart: _startNavigation,
            onClose: _closeRoutes,
            onSearchAlong: _searchAlong,
            alongCounts: {
              for (final entry in _along.entries) entry.key: entry.value.length,
            },
            alongLoading: _alongLoading,
            stops: [for (final stop in _stops) stop.name],
            weatherWarning: _weatherWarning,
            onRemoveStop: _removeStop,
            onSaveOffline: _saveRouteOffline,
            onOpenPreferences: _openRoutePreferences,
            preferencesSummary: _routePrefsSummary,
            onShowSteps: _showRouteSteps,
            offlineProgress: _offlineProgress,
            isSavedOffline: identical(_offlineSavedFor, _routePoints),
            arrivalWarning: _arrivalWarning,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(children: children),
    );
  }

  /// Segnaposto fisso al centro, barra in alto e pulsante "Fatto".
  List<Widget> _buildChooseOnMap(bool isStart) {
    final color = isStart ? AppPalette.startGreen : AppPalette.primary;
    return [
      // La punta del segnaposto indica il centro della mappa.
      IgnorePointer(
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: RouteEndpointMarker(
              color: color,
              icon: isStart ? Icons.trip_origin_rounded : Icons.flag_rounded,
              label: isStart ? 'Partenza' : 'Arrivo',
            ),
          ),
        ),
      ),
      SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kSearchPanelMaxWidth),
              child: ChooseOnMapBar(
                isStart: isStart,
                onCancel: () => setState(() => _choosingOnMapFor = null),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        bottom: 28,
        child: SafeArea(
          top: false,
          child: Center(
            child: FilledButton.icon(
              onPressed: _confirmChooseOnMap,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Fatto'),
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
            ),
          ),
        ),
      ),
    ];
  }

  /// Il percorso scelto; in auto il tratto da guidare è blu scuro e quello
  /// in sedia a rotelle dopo il parcheggio ha il colore solito.
  List<Polyline<Object>> _selectedRoutePolylines() {
    if (_routePoints.isEmpty) return const [];
    final route = _selectedRouteIndex < _routes.length
        ? _routes[_selectedRouteIndex]
        : null;
    final split = route != null &&
            route.usesCar &&
            identical(route.points, _routePoints)
        ? route.driveEndIndex
        : 0;
    if (split <= 0) {
      return [
        Polyline(
          points: _routePoints,
          strokeWidth: 8,
          color: AppPalette.primary,
          borderColor: Colors.white,
          borderStrokeWidth: 2.5,
        ),
      ];
    }
    return [
      Polyline(
        points: _routePoints.sublist(0, split + 1),
        strokeWidth: 8,
        color: AppPalette.driveRoute,
        borderColor: Colors.white,
        borderStrokeWidth: 2.5,
      ),
      if (split < _routePoints.length - 1)
        Polyline(
          points: _routePoints.sublist(split),
          strokeWidth: 8,
          color: AppPalette.primary,
          borderColor: Colors.white,
          borderStrokeWidth: 2.5,
        ),
    ];
  }

  Widget _buildMap(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final layers = <Widget>[
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'it.enactusunibs.freeway',
        // Usa tile native anche sui display ad alta densità: la modalità
        // retina simulata richiede il livello successivo, assente oltre 19.
        maxNativeZoom: _maxZoom.toInt(),
        maxZoom: _maxZoom,
        // Annulla il download delle tile uscite dallo schermo: mappa più
        // reattiva sul web e meno richieste ai server di OpenStreetMap.
        // Le tile salvate per il percorso si leggono dall'archivio, anche
        // senza rete; le altre arrivano dalla rete annullando quelle uscite
        // dallo schermo.
        tileProvider: RouteTileProvider(_offlineRoute),
        tileBuilder: isDark ? darkTileBuilder : lightTileBuilder,
      ),
    ];

    if (_routes.isNotEmpty) {
      final polylines = <Polyline<Object>>[
        for (var i = 0; i < _routes.length; i++)
          if (i != _selectedRouteIndex)
            Polyline(
              points: _routes[i].points,
              strokeWidth: 7,
              color: AppPalette.alternativeRoute.withValues(alpha: 0.55),
              borderStrokeWidth: 1,
              borderColor: Colors.white.withValues(alpha: 0.4),
            ),
        ..._selectedRoutePolylines(),
      ];
      layers.add(PolylineLayer(polylines: polylines));
    } else if (_routePoints.isNotEmpty) {
      layers.add(
        PolylineLayer(
          polylines: [
            Polyline(
              points: _routePoints,
              strokeWidth: 7,
              color: AppPalette.primary,
              borderColor: Colors.white,
              borderStrokeWidth: 2.5,
            ),
          ],
        ),
      );
    }

    // Cerchio di incertezza intorno alla posizione, come in Google Maps.
    final accuracy = _userAccuracy;
    if (_userLocation != null && accuracy != null && accuracy > 15) {
      layers.add(
        CircleLayer(
          circles: [
            CircleMarker(
              point: _userLocation!,
              radius: accuracy,
              useRadiusInMeter: true,
              color: AppPalette.userBlue.withValues(alpha: 0.12),
              borderColor: AppPalette.userBlue.withValues(alpha: 0.4),
              borderStrokeWidth: 1,
            ),
          ],
        ),
      );
    }

    layers.add(
      MarkerClusterLayerWidget(
        options: MarkerClusterLayerOptions(
          maxClusterRadius: 45,
          rotate: true,
          size: const Size(40, 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(50),
          markers: _filteredObstacles
              .map(
                (obstacle) => Marker(
                  point: obstacle.position,
                  width: 40,
                  height: 40,
                  rotate: true,
                  child: ObstacleMarker(
                    color: obstacle.color,
                    icon: obstacle.icon,
                    label: 'Ostacolo: ${obstacle.type}',
                    onTap: () => _openObstacle(obstacle),
                  ),
                ),
              )
              .toList(),
          builder: (context, markers) => ClusterBadge(count: markers.length),
        ),
      ),
    );

    layers.add(
      MarkerLayer(
        // Con la mappa ruotata le icone restano dritte.
        rotate: true,
        markers: [
          if (_startPoint != null && _choosingOnMapFor != true)
            Marker(
              point: _startPoint!,
              width: 44,
              height: 48,
              alignment: Alignment.bottomCenter,
              child: const RouteEndpointMarker(
                color: AppPalette.startGreen,
                icon: Icons.trip_origin_rounded,
                label: 'Partenza',
              ),
            ),
          if (_endPoint != null && _choosingOnMapFor != false)
            Marker(
              point: _endPoint!,
              width: 44,
              height: 48,
              alignment: Alignment.bottomCenter,
              child: _stage == SearchPhase.directions
                  ? const RouteEndpointMarker(
                      color: AppPalette.primary,
                      icon: Icons.flag_rounded,
                      label: 'Arrivo',
                    )
                  : const RouteEndpointMarker(
                      color: AppPalette.primary,
                      icon: Icons.place_rounded,
                      label: 'Luogo cercato',
                    ),
            ),
          if (_stage != SearchPhase.search && _choosingOnMapFor == null)
            for (final entrance
                in _placeAccessibility?.entrances ?? const <PlaceEntrance>[])
              // Nelle indicazioni l'ingresso scelto è già la bandierina.
              if (_stage != SearchPhase.directions ||
                  entrance.position != _endPoint)
                Marker(
                  point: entrance.position,
                  width: 30,
                  height: 30,
                  child: EntranceMarker(
                    entrance: entrance,
                    isDestination: _endPoint == entrance.position,
                    onTap: () => _chooseEntrance(entrance),
                  ),
                ),
          for (final places in _along.values)
            for (final place in places)
              if (!_stops.any((s) => s.position == place.position))
                Marker(
                  point: place.position,
                  width: 28,
                  height: 28,
                  child: AlongPlaceMarker(
                    place: place,
                    onTap: () => _openAlongPlace(place),
                  ),
                ),
          if (_showParkingLayer)
            for (final parking in _layerParkings)
              Marker(
                point: parking.position,
                width: 28,
                height: 28,
                child: ParkingMarker(
                  label: 'Parcheggio per disabili: ${parking.summary}',
                  onTap: () => _openParking(parking),
                ),
              ),
          for (final route in _routes)
            if (route.parking != null &&
                !_layerParkings.any((p) => p.id == route.parking!.id))
              Marker(
                point: route.parking!.position,
                width: 30,
                height: 30,
                child: ParkingMarker(
                  label: 'Parcheggio per disabili: ${route.parking!.summary}',
                  isSelected: route == _routes[_selectedRouteIndex],
                  onTap: () => _openParking(route.parking!),
                ),
              ),
          for (var i = 0; i < _stops.length; i++)
            Marker(
              point: _stops[i].position,
              width: 30,
              height: 30,
              child: StopMarker(number: i + 1, label: _stops[i].name),
            ),
          if (_userLocation != null)
            Marker(
              point: _userLocation!,
              width: 72,
              height: 72,
              // Gira con la mappa: il cono punta così nella direzione vera.
              rotate: false,
              child: UserLocationDot(heading: _coneHeading),
            ),
        ],
      ),
    );

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _zoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        onTap: (_, _) => FocusScope.of(context).unfocus(),
        onLongPress: (_, point) {
          if (_choosingOnMapFor == null) _reportObstacle(point);
        },
        onPositionChanged: (_, _) => _onMapMoved(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: layers,
    );
  }
}
