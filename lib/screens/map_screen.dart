import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../models/route_option.dart';
import '../services/geocoding_service.dart';
import '../services/instruction_translator.dart';
import '../services/location_service.dart';
import '../services/navigation_service.dart';
import '../services/obstacle_service.dart';
import '../services/routing_service.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/map_widgets.dart';
import '../widgets/navigation_panel.dart';
import '../widgets/obstacle_sheets.dart';
import '../widgets/route_options_sheet.dart';
import '../widgets/search_panel.dart';
import '../widgets/top_bar.dart';

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
  final ObstacleService _obstacleService =
      ObstacleService(FirebaseFirestore.instance);
  final NavigationService _navigationService = NavigationService();
  final TtsService _ttsService = TtsService();

  double _zoom = 13;
  LatLng _center = const LatLng(45.4642, 9.19); // Milano
  LatLng? _userLocation;

  List<LatLng> _routePoints = [];
  List<RouteOption> _routes = [];
  int _selectedRouteIndex = 0;

  LatLng? _startPoint;
  LatLng? _endPoint;

  bool _isCalculating = false;
  bool _isRecalculating = false;
  bool _isLocatingStart = false;
  bool _isLocatingEnd = false;
  bool _isLocatingUser = false;
  bool _isNavigating = false;
  NavigationUpdate? _navigationUpdate;
  String _voiceLanguage = 'it';
  StreamSubscription<NavigationUpdate>? _navigationSubscription;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  List<Map<String, dynamic>> _startSuggestions = [];
  List<Map<String, dynamic>> _endSuggestions = [];
  bool _isSearchExpanded = true;
  bool _showReportHint = true;

  List<Obstacle> _obstacles = [];
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
    _obstacleService.listen((obstacles) {
      if (mounted) setState(() => _obstacles = obstacles);
    });
    _mapController.mapEventStream.listen((event) {
      if (!mounted) return;
      _center = event.camera.center;
      _zoom = event.camera.zoom;
    });
  }

  @override
  void dispose() {
    _ttsService.stop();
    _ttsService.reset();
    _navigationSubscription?.cancel();
    _navigationService.dispose();
    _obstacleService.dispose();
    _geocodingService.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {Color? iconColor, required IconData icon}) {
    final colors = AppColors.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? colors.surfaceElevated
          : AppPalette.snackBarLight,
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.white, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    ));
  }

  void _showError(String message, IconData icon) => _showSnack(message, icon: icon);

  // --- Ricerca indirizzi ---------------------------------------------------

  void _onSearchChanged(String query, bool isStart) {
    _geocodingService.searchDebounced(query, (results) {
      if (!mounted) return;
      setState(() {
        if (isStart) {
          _startSuggestions = results;
        } else {
          _endSuggestions = results;
        }
      });
    });
  }

  void _selectSuggestion(Map<String, dynamic> place, bool isStart) {
    final lat = double.parse(place['lat'].toString());
    final lon = double.parse(place['lon'].toString());
    final label = formatPlace(place);
    var text = label.title;
    if (label.subtitle.isNotEmpty) text = '$text, ${label.subtitle.split(',').first}';

    setState(() => _setPoint(isStart, LatLng(lat, lon), text));
    FocusScope.of(context).unfocus();
  }

  void _setPoint(bool isStart, LatLng point, String text) {
    if (isStart) {
      _startPoint = point;
      _startController.text = text;
      _startSuggestions = [];
    } else {
      _endPoint = point;
      _endController.text = text;
      _endSuggestions = [];
    }
  }

  void _clearPoint({required bool isStart}) {
    setState(() {
      if (isStart) {
        _startController.clear();
        _startSuggestions = [];
        _startPoint = null;
      } else {
        _endController.clear();
        _endSuggestions = [];
        _endPoint = null;
      }
      _routePoints = [];
      _routes = [];
      _isSearchExpanded = true;
    });
  }

  void _swapPoints() {
    setState(() {
      final start = _startPoint;
      _startPoint = _endPoint;
      _endPoint = start;
      final startText = _startController.text;
      _startController.text = _endController.text;
      _endController.text = startText;
      _startSuggestions = [];
      _endSuggestions = [];
    });
    if (_startPoint != null && _endPoint != null) _calculateRoute();
  }

  // --- Percorsi ------------------------------------------------------------

  Future<void> _calculateRoute() async {
    final start = _startPoint;
    final end = _endPoint;
    if (start == null || end == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isCalculating = true;
      _routes = [];
    });
    try {
      final routes = await _routingService.getRoutes(start, end, _obstacles);
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _selectedRouteIndex = 0;
        _routePoints = routes.isNotEmpty ? routes.first.points : [];
        _isCalculating = false;
        _isSearchExpanded = routes.isEmpty;
      });
      _fitRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCalculating = false);
      _showError(
        'Non è stato possibile calcolare il percorso. Riprova.',
        Icons.error_outline_rounded,
      );
    }
  }

  void _selectRoute(int index) {
    if (index < 0 || index >= _routes.length) return;
    setState(() {
      _selectedRouteIndex = index;
      _routePoints = _routes[index].points;
    });
    _fitRoute();
  }

  void _closeRoutes() {
    setState(() {
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
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(48, 150, 48, 260),
    ));
  }

  // --- Navigazione ---------------------------------------------------------

  void _startNavigation() {
    if (_routes.isEmpty) return;
    final route = _routes[_selectedRouteIndex];
    setState(() => _isNavigating = true);
    _navigationService.start(route);
    _navigationSubscription?.cancel();
    _navigationSubscription =
        _navigationService.updates.listen(_onNavigationUpdate);
  }

  void _onNavigationUpdate(NavigationUpdate update) {
    if (!mounted) return;
    setState(() {
      _navigationUpdate = update;
      _userLocation = update.position;
    });
    _mapController.move(update.position, 17.5);

    final instruction = InstructionTranslator(_voiceLanguage)
        .translate(update.currentStep.instruction);
    final distance = update.distanceToNextStep >= 1000
        ? '${(update.distanceToNextStep / 1000).toStringAsFixed(1)} chilometri'
        : '${update.distanceToNextStep.round()} metri';
    final String speech;
    if (update.hasArrived) {
      speech = _voiceLanguage == 'it'
          ? 'Sei arrivato a destinazione'
          : 'You have reached destination';
    } else {
      speech = _voiceLanguage == 'it'
          ? 'Tra $distance, $instruction'
          : 'In $distance, $instruction';
    }
    _ttsService.speak(speech, _voiceLanguage);

    if (update.isOffRoute && !_isRecalculating && _endPoint != null) {
      _recalculate(update.position);
    }
  }

  Future<void> _recalculate(LatLng from) async {
    _isRecalculating = true;
    try {
      final routes = await _routingService.getRoutes(from, _endPoint!, _obstacles);
      if (mounted && routes.isNotEmpty && _isNavigating) {
        setState(() {
          _routes = routes;
          _selectedRouteIndex = 0;
          _routePoints = routes.first.points;
        });
        _navigationService.start(routes.first);
      }
    } catch (_) {
      // Si riprova al prossimo aggiornamento di posizione.
    } finally {
      _isRecalculating = false;
    }
  }

  void _stopNavigation() {
    _ttsService.stop();
    _ttsService.reset();
    _navigationSubscription?.cancel();
    _navigationSubscription = null;
    _navigationService.stop();
    setState(() {
      _isNavigating = false;
      _navigationUpdate = null;
    });
    _fitRoute();
  }

  // --- Posizione -----------------------------------------------------------

  Future<void> _locateUser({bool showErrors = false}) async {
    setState(() => _isLocatingUser = true);
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocatingUser = false);
    final position = result.position;
    if (position != null) {
      setState(() => _userLocation = _center = position);
      _mapController.move(_center, 16);
    } else if (showErrors) {
      _showError(
        result.error ?? 'Posizione non disponibile',
        Icons.location_disabled_rounded,
      );
    }
  }

  Future<void> _useMyLocation({required bool isStart}) async {
    setState(() {
      if (isStart) {
        _isLocatingStart = true;
      } else {
        _isLocatingEnd = true;
      }
    });
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _isLocatingStart = false;
      } else {
        _isLocatingEnd = false;
      }
    });

    final position = result.position;
    if (position == null) {
      _showError(
        result.error ?? 'Posizione non disponibile',
        Icons.location_disabled_rounded,
      );
      return;
    }

    setState(() => _center = _userLocation = position);
    _mapController.move(position, 16);
    final address = await _geocodingService.reverse(position);
    final label = address != null && address.isNotEmpty
        ? '$address (La mia posizione)'
        : 'La mia posizione attuale';
    if (!mounted) return;
    setState(() => _setPoint(isStart, position, label));
    if (result.isApproximate) {
      _showError(
        'Posizione rilevata dalla rete. Per il GPS preciso consenti la '
        'posizione dal lucchetto nella barra del browser.',
        Icons.gps_not_fixed_rounded,
      );
    }
    if (_startPoint != null && _endPoint != null) _calculateRoute();
  }

  // --- Ostacoli ------------------------------------------------------------

  Future<void> _reportObstacle(LatLng point) async {
    final type = await showReportObstacleSheet(context);
    if (type == null) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await _obstacleService.add(point, type, userId);
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Non è stato possibile salvare la segnalazione. Riprova.',
        Icons.error_outline_rounded,
      );
      return;
    }
    if (!mounted) return;
    _showSnack(
      'Ostacolo segnalato. Grazie per il contributo!',
      iconColor: AppColors.of(context).success,
      icon: Icons.check_circle_rounded,
    );
  }

  Future<void> _openObstacle(Obstacle obstacle) async {
    final remove = await showObstacleDetailsSheet(context, obstacle);
    if (remove != true || !mounted) return;
    try {
      await _obstacleService.remove(obstacle.id);
      if (!mounted) return;
      _showSnack(
        'Ostacolo rimosso dalla mappa.',
        iconColor: AppColors.of(context).success,
        icon: Icons.check_circle_rounded,
      );
      if (_startPoint != null && _endPoint != null) _calculateRoute();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      _showError(
        error.code == 'permission-denied'
            ? 'Per rimuovere le segnalazioni di altri utenti accedi con '
                'un account (non come ospite).'
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

  // --- Zoom ----------------------------------------------------------------

  void _zoomIn() {
    _zoom = (_zoom + 1).clamp(2, 19).toDouble();
    _mapController.move(_center, _zoom);
  }

  void _zoomOut() {
    _zoom = (_zoom - 1).clamp(2, 19).toDouble();
    _mapController.move(_center, _zoom);
  }

  // --- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasRoutes = _routes.isNotEmpty;
    final double controlsBottom =
        _isNavigating ? 32 : (hasRoutes ? 268 : (_showReportHint ? 80 : 32));

    final children = <Widget>[
      _buildMap(context),
      const Positioned(left: 12, bottom: 4, child: OsmAttribution()),
    ];

    if (!_isNavigating) {
      final Widget search = _isSearchExpanded
          ? SearchPanel(
              key: const ValueKey('search-expanded'),
              startController: _startController,
              endController: _endController,
              startSuggestions: _startSuggestions,
              endSuggestions: _endSuggestions,
              isLocatingStart: _isLocatingStart,
              isLocatingEnd: _isLocatingEnd,
              isCalculating: _isCalculating,
              canCalculate: _startPoint != null && _endPoint != null,
              onStartChanged: (q) => _onSearchChanged(q, true),
              onEndChanged: (q) => _onSearchChanged(q, false),
              onSelectSuggestion: _selectSuggestion,
              onUseMyLocation: _useMyLocation,
              onClear: _clearPoint,
              onSwap: _swapPoints,
              onCalculate: _calculateRoute,
            )
          : CollapsedSearchBar(
              key: const ValueKey('search-collapsed'),
              startText: _startController.text,
              endText: _endController.text,
              onTap: () => setState(() => _isSearchExpanded = true),
            );

      children.add(SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TopBar(onLogout: () => FirebaseAuth.instance.signOut()),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: search,
              ),
              const SizedBox(height: 12),
              CategoryFilterBar(
                categories: _categories,
                selected: _selectedCategory,
                countFor: _countForCategory,
                onSelected: (category) =>
                    setState(() => _selectedCategory = category),
              ),
            ],
          ),
        ),
      ));
    }

    if (_isNavigating && _navigationUpdate != null) {
      children.add(Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: NavigationPanel(
          update: _navigationUpdate!,
          language: _voiceLanguage,
          isMuted: _ttsService.muted,
          onStop: _stopNavigation,
          onToggleMute: () => setState(() {
            _ttsService.muted = !_ttsService.muted;
            if (_ttsService.muted) _ttsService.stop();
          }),
          onLanguageChanged: (language) =>
              setState(() => _voiceLanguage = language),
        ),
      ));
    }

    children.add(AnimatedPositioned(
      right: 12,
      bottom: controlsBottom,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: MapControls(
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        onLocate: () => _locateUser(showErrors: true),
        isLocating: _isLocatingUser,
      ),
    ));

    if (!hasRoutes && !_isNavigating && _showReportHint) {
      children.add(Positioned(
        left: 12,
        right: 60,
        bottom: 24,
        child: ReportHint(
          onClose: () => setState(() => _showReportHint = false),
        ),
      ));
    }

    if (hasRoutes && !_isNavigating) {
      children.add(Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: RouteOptionsSheet(
          routes: _routes,
          selectedIndex: _selectedRouteIndex,
          onSelect: _selectRoute,
          onStart: _startNavigation,
          onClose: _closeRoutes,
        ),
      ));
    }

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      body: Stack(children: children),
    );
  }

  Widget _buildMap(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final layers = <Widget>[
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'it.enactusunibs.freeway',
        // Annulla il download delle tile uscite dallo schermo: mappa più
        // reattiva sul web e meno richieste ai server di OpenStreetMap.
        tileProvider: CancellableNetworkTileProvider(),
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
        if (_routePoints.isNotEmpty)
          Polyline(
            points: _routePoints,
            strokeWidth: 8,
            color: AppPalette.primary,
            borderColor: Colors.white,
            borderStrokeWidth: 2.5,
          ),
      ];
      layers.add(PolylineLayer(polylines: polylines));
    } else if (_routePoints.isNotEmpty) {
      layers.add(PolylineLayer(polylines: [
        Polyline(
          points: _routePoints,
          strokeWidth: 7,
          color: AppPalette.primary,
          borderColor: Colors.white,
          borderStrokeWidth: 2.5,
        ),
      ]));
    }

    layers.add(MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 45,
        size: const Size(40, 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(50),
        markers: _filteredObstacles
            .map((obstacle) => Marker(
                  point: obstacle.position,
                  width: 40,
                  height: 40,
                  child: ObstacleMarker(
                    color: obstacle.color,
                    icon: obstacle.icon,
                    onTap: () => _openObstacle(obstacle),
                  ),
                ))
            .toList(),
        builder: (context, markers) => ClusterBadge(count: markers.length),
      ),
    ));

    layers.add(MarkerLayer(markers: [
      if (_startPoint != null)
        Marker(
          point: _startPoint!,
          width: 44,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: const RouteEndpointMarker(
            color: AppPalette.startGreen,
            icon: Icons.trip_origin_rounded,
          ),
        ),
      if (_endPoint != null)
        Marker(
          point: _endPoint!,
          width: 44,
          height: 48,
          alignment: Alignment.bottomCenter,
          child: const RouteEndpointMarker(
            color: AppPalette.primary,
            icon: Icons.flag_rounded,
          ),
        ),
      if (_userLocation != null)
        Marker(
          point: _userLocation!,
          width: 46,
          height: 46,
          child: const UserLocationDot(),
        ),
    ]));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: _zoom,
        onTap: (_, _) => FocusScope.of(context).unfocus(),
        onLongPress: (_, point) => _reportObstacle(point),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: layers,
    );
  }
}
