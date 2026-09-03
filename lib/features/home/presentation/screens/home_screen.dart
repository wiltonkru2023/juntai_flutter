import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';
import '../../../map/data/location_service.dart';
import '../../../discoveries/data/discovery_service.dart';
import '../../../discoveries/domain/discovery.dart';
import '../../../discoveries/presentation/widgets/post_metric_tracker.dart';
import '../widgets/activity_card.dart';
import '../widgets/category_row.dart';
import '../widgets/home_header.dart';
import '../widgets/urgent_open_slots_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ActivityCategory? selected;

  Position? currentPosition;

  bool locating = false;

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
    } catch (_) {
      // Home continua funcionando sem GPS.
    } finally {
      if (mounted) {
        setState(() => locating = false);
      }
    }
  }

  double? _calculateDistance(
    Activity activity,
  ) {
    final position = currentPosition;

    if (position == null) {
      return null;
    }

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

  Stream<List<Activity>> get activitiesStream {
    return FirebaseFirestore.instance
        .collection('activities')
        .where(
          'isPrivate',
          isEqualTo: false,
        )
        .snapshots()
        .map((snapshot) {
      final activities = snapshot.docs
          .map(Activity.fromFirestore)
          .where(
            (activity) =>
                activity.status == 'active' &&
                activity.startsAt.isAfter(
                  DateTime.now(),
                ),
          )
          .map((activity) {
        final distance = _calculateDistance(activity);

        if (distance == null) {
          return activity;
        }

        return activity.copyWith(
          distanceKm: distance,
        );
      }).toList();

      if (currentPosition != null) {
        activities.sort(
          (a, b) {
            final aHasLocation = !(a.latitude == 0 && a.longitude == 0);

            final bHasLocation = !(b.latitude == 0 && b.longitude == 0);

            if (aHasLocation && !bHasLocation) {
              return -1;
            }

            if (!aHasLocation && bHasLocation) {
              return 1;
            }

            if (aHasLocation && bHasLocation) {
              return a.distanceKm.compareTo(
                b.distanceKm,
              );
            }

            return a.startsAt.compareTo(
              b.startsAt,
            );
          },
        );
      } else {
        activities.sort(
          (a, b) => a.startsAt.compareTo(
            b.startsAt,
          ),
        );
      }

      return activities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Activity>>(
      stream: activitiesStream,
      builder: (context, snapshot) {
        final allActivities = snapshot.data ?? <Activity>[];

        final activities = selected == null
            ? allActivities
            : allActivities
                .where(
                  (activity) => activity.category == selected,
                )
                .toList();

        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadLocation,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: HomeHeader(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      10,
                    ),
                    child: AppSearchField(
                      readOnly: true,
                      onTap: () => context.push('/search'),
                      onFilter: () => context.push('/filters'),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: CategoryRow(
                    selected: selected,
                    onSelected: (category) {
                      setState(() {
                        selected = selected == category ? null : category;
                      });
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: _DiscoveriesPreview(position: currentPosition),
                ),
                SliverToBoxAdapter(
                  child: UrgentOpenSlotsSection(position: currentPosition),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      24,
                      20,
                      12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          currentPosition != null
                              ? 'Perto de você'
                              : 'Atividades',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (locating) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ],
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go('/map'),
                          child: const Text(
                            'Ver no mapa ›',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 42,
                            color: AppColors.error,
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          const Text(
                            'Não foi possível carregar as atividades.',
                          ),
                          const SizedBox(
                            height: 6,
                          ),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (activities.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        50,
                        24,
                        50,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 54,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 14),
                          Text(
                            'Nenhuma atividade por aqui ainda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Crie a primeira atividade!',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      22,
                    ),
                    sliver: SliverList.separated(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];

                        return SizedBox(
                          height: 196,
                          child: ActivityCard(
                            activity: activity,
                            onJoin: () {
                              context.go(
                                '/activity/${activity.id}',
                              );
                            },
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(
                        height: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiscoveriesPreview extends StatelessWidget {
  const _DiscoveriesPreview({this.position});

  final Position? position;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Discovery>>(
        stream: DiscoveryService().watchPublished(
          limit: 6,
          latitude: position?.latitude,
          longitude: position?.longitude,
        ),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Discovery>[];
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  const Icon(Icons.explore_rounded, color: AppColors.primary),
                  const SizedBox(width: 7),
                  const Expanded(
                      child: Text('Descubra perto de você',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w800))),
                  TextButton(
                      onPressed: () => context.push('/discover'),
                      child: const Text('Ver todos ›')),
                ]),
              ),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    return InkWell(
                      onTap: () => context.push('/discovery/${d.id}'),
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(18)),
                        child: Stack(children: [
                          PostMetricTracker(postId: d.id, event: 'impression'),
                          Row(children: [
                            if ((d.coverUrl ?? '').isNotEmpty)
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(d.coverUrl!,
                                      width: 82,
                                      height: 100,
                                      fit: BoxFit.cover))
                            else
                              const SizedBox(
                                  width: 82,
                                  child: Icon(Icons.storefront_rounded,
                                      size: 42, color: AppColors.primary)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                  if (d.sponsored)
                                    const Text('PATROCINADO',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textSecondary)),
                                  Text(d.businessName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Text(d.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(d.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ])),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
          );
        },
      );
}
