import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';
import '../../data/location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();

  Position? currentPosition;
  String? selectedId;
  bool locating = false;
  bool mapReady = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (locating) return;

    setState(() => locating = true);

    try {
      final position = await LocationService.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        currentPosition = position;
      });

      if (mapReady) {
        mapController.move(
          LatLng(position.latitude, position.longitude),
          14.5,
        );
      }
    } catch (_) {
      // O mapa continua utilizável sem GPS.
    } finally {
      if (mounted) {
        setState(() => locating = false);
      }
    }
  }

  double? _distance(Activity activity) {
    final position = currentPosition;

    if (position == null) return null;

    if (activity.latitude == 0 && activity.longitude == 0) {
      return null;
    }

    return LocationService.distanceKm(
      fromLatitude: position.latitude,
      fromLongitude: position.longitude,
      toLatitude: activity.latitude,
      toLongitude: activity.longitude,
    );
  }

  Stream<List<Activity>> get _activities {
    return FirebaseFirestore.instance
        .collection('activities')
        .where('isPrivate', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map(Activity.fromFirestore)
          .where((activity) => activity.status == 'active')
          .where(
            (activity) =>
                activity.latitude.abs() <= 90 &&
                activity.longitude.abs() <= 180 &&
                !(activity.latitude == 0 && activity.longitude == 0),
          )
          .toList();

      list.sort((a, b) {
        final distanceA = _distance(a) ?? double.infinity;
        final distanceB = _distance(b) ?? double.infinity;
        return distanceA.compareTo(distanceB);
      });

      return list;
    });
  }

  LatLng get _initialCenter {
    final position = currentPosition;

    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }

    // Centro aproximado do Brasil enquanto o GPS carrega.
    return const LatLng(-14.2350, -51.9253);
  }

  Future<void> _openOsmCopyright() async {
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 18, 12),
            child: Row(
              children: [
                const Text(
                  'Mapa',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => context.push('/filters'),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Filtrar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Activity>>(
              stream: _activities,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Erro ao carregar atividades:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final activities = snapshot.data ?? <Activity>[];
                final selected = selectedId == null
                    ? null
                    : activities.where((a) => a.id == selectedId).firstOrNull;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: _initialCenter,
                          initialZoom: currentPosition == null ? 4.2 : 14.5,
                          minZoom: 3,
                          maxZoom: 19,
                          onMapReady: () {
                            mapReady = true;

                            final position = currentPosition;
                            if (position != null) {
                              mapController.move(
                                LatLng(
                                  position.latitude,
                                  position.longitude,
                                ),
                                14.5,
                              );
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'app.juntai.juntai',
                            maxNativeZoom: 19,
                          ),
                          MarkerLayer(
                            markers: [
                              if (currentPosition != null)
                                Marker(
                                  point: LatLng(
                                    currentPosition!.latitude,
                                    currentPosition!.longitude,
                                  ),
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: .18,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              for (final activity in activities)
                                Marker(
                                  point: LatLng(
                                    activity.latitude,
                                    activity.longitude,
                                  ),
                                  width: 50,
                                  height: 58,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedId = activity.id;
                                      });

                                      mapController.move(
                                        LatLng(
                                          activity.latitude,
                                          activity.longitude,
                                        ),
                                        15,
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: activity.category.color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: .22,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            activity.category.icon,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: activity.category.color,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: .88),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _openOsmCopyright,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Text(
                              '© OpenStreetMap contributors',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: FloatingActionButton.small(
                        heroTag: 'map-location',
                        onPressed: locating ? null : _loadLocation,
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        child: locating
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ),
                    if (selected != null)
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 72,
                        child: _SelectedCard(
                          activity: selected,
                          distance: _distance(selected),
                          onClose: () {
                            setState(() => selectedId = null);
                          },
                        ),
                      ),
                    if (activities.isEmpty)
                      Positioned(
                        top: 12,
                        left: 18,
                        right: 18,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .08),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Ainda não há atividades públicas com localização válida para mostrar no mapa.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.activity,
    required this.distance,
    required this.onClose,
  });

  final Activity activity;
  final double? distance;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 82,
              decoration: BoxDecoration(
                color: activity.category.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                activity.category.icon,
                color: activity.category.color,
                size: 38,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                  if (distance != null)
                    Text(
                      '${distance!.toStringAsFixed(1).replaceAll('.', ',')} km',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    activity.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  FilledButton(
                    onPressed: () => context.go(
                      '/activity/${activity.id}',
                    ),
                    child: const Text('Ver detalhes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
