import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart' show formatDistance;
import '../services/trip_share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/map_widgets.dart';

/// Pagina aperta da chi ha ricevuto il link di "Condividi il viaggio": la
/// posizione di chi viaggia, la destinazione e quando arriva. Non serve un
/// account.
class TripViewerScreen extends StatefulWidget {
  const TripViewerScreen({
    super.key,
    required this.tripId,
    this.trips,
    this.onOpenApp,
    this.clock = DateTime.now,
    this.showTiles = true,
  });

  final String tripId;

  /// Aggiornamenti del viaggio; per i test.
  final Stream<SharedTrip?>? trips;

  /// "Apri FreeWay": la mappa normale, senza il viaggio.
  final VoidCallback? onOpenApp;
  final DateTime Function() clock;

  /// Senza tile (nei test non c'è rete).
  final bool showTiles;

  @override
  State<TripViewerScreen> createState() => _TripViewerScreenState();
}

class _TripViewerScreenState extends State<TripViewerScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<SharedTrip?>? _subscription;
  Timer? _ticker;
  SharedTrip? _trip;
  bool _loading = true;
  bool _followed = false;

  @override
  void initState() {
    super.initState();
    final stream =
        widget.trips ??
        TripShareService.watch(FirebaseFirestore.instance, widget.tripId);
    _subscription = stream.listen((trip) {
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _loading = false;
      });
      if (trip != null && !_isOver(trip)) _follow(trip);
    });
    // Aggiorna "aggiornata N s fa" e la scadenza anche senza novità.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  bool _isOver(SharedTrip trip) => trip.isExpired(widget.clock());

  void _follow(SharedTrip trip) {
    try {
      if (!_followed) {
        _followed = true;
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [trip.position, trip.destination],
            padding: const EdgeInsets.fromLTRB(48, 96, 48, 260),
            maxZoom: 17,
          ),
        );
      } else {
        _mapController.move(trip.position, _mapController.camera.zoom);
      }
    } catch (_) {
      // La mappa non è ancora pronta: la posizione iniziale basta.
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final over = trip == null || _isOver(trip);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: trip?.position ?? const LatLng(45.5389, 10.2200),
              initialZoom: 15,
              maxZoom: 19,
            ),
            children: [
              if (widget.showTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'it.enactusunibs.freeway',
                  maxNativeZoom: 19,
                  maxZoom: 19,
                  tileProvider: CancellableNetworkTileProvider(),
                  tileBuilder: isDark ? darkTileBuilder : lightTileBuilder,
                ),
              if (trip != null && !over)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: trip.destination,
                      width: 44,
                      height: 48,
                      alignment: Alignment.bottomCenter,
                      child: const RouteEndpointMarker(
                        color: AppPalette.primary,
                        icon: Icons.flag_rounded,
                        label: 'Destinazione',
                      ),
                    ),
                    Marker(
                      point: trip.position,
                      width: 46,
                      height: 46,
                      child: Semantics(
                        label: 'Posizione di chi viaggia',
                        child: const UserLocationDot(),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Positioned(left: 12, bottom: 4, child: OsmAttribution()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _card(context, trip, over),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, SharedTrip? trip, bool over) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final now = widget.clock();
    final String title;
    final List<String> lines;
    IconData icon = Icons.share_location_rounded;
    Color iconColor = AppPalette.primary;
    if (_loading) {
      title = 'Carico il viaggio…';
      lines = const [];
    } else if (trip == null || over) {
      title = 'La condivisione è terminata';
      lines = const [
        'Chi viaggiava ha interrotto la condivisione, oppure il link è '
            'scaduto o non è valido.',
      ];
      icon = Icons.location_off_outlined;
      iconColor = colors.textTertiary;
    } else if (trip.arrived) {
      title = 'Arrivo a destinazione';
      lines = ['Ha raggiunto ${trip.destinationName}.'];
      icon = Icons.flag_rounded;
      iconColor = colors.success;
    } else {
      title = 'In viaggio verso ${trip.destinationName}';
      final meters = trip.remainingMeters;
      final seconds = trip.remainingSeconds;
      lines = [
        if (seconds != null && meters != null)
          'Arrivo previsto tra ${_minutes(seconds)} '
              '(${formatDistance(meters)})',
        trip.isStale(now)
            ? 'Ultimo aggiornamento ${_ago(trip.updatedAt!, now)}: '
                  'forse è senza segnale.'
            : trip.updatedAt == null
            ? 'Posizione in tempo reale'
            : 'Posizione aggiornata ${_ago(trip.updatedAt!, now)}',
      ];
    }
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: softShadow(colors),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: textTheme.titleMedium),
                        for (final line in lines)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(line, style: textTheme.bodyMedium),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Condiviso con FREE WAY. La posizione è visibile solo a chi ha '
              'il link e smette di esserlo all\'arrivo.',
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
            if (widget.onOpenApp != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onOpenApp,
                  child: const Text('Apri FREE WAY'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _minutes(double seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes <= 1) return '1 minuto';
    if (minutes < 60) return '$minutes minuti';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  static String _ago(DateTime date, DateTime now) {
    final elapsed = now.difference(date);
    if (elapsed.inSeconds < 30) return 'adesso';
    if (elapsed.inMinutes < 1) return 'meno di un minuto fa';
    if (elapsed.inMinutes == 1) return '1 minuto fa';
    return '${elapsed.inMinutes} minuti fa';
  }
}
