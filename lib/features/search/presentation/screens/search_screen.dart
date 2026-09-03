import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';
import '../../../home/presentation/widgets/activity_card.dart';
import '../../../map/data/location_service.dart';
import '../../providers/search_filters_provider.dart';
import '../widgets/search_result_user.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final controller = TextEditingController();

  final debouncer = Debouncer(
    const Duration(milliseconds: 350),
  );

  late final TabController tabs;

  String query = '';

  Position? position;

  @override
  void initState() {
    super.initState();

    tabs = TabController(
      length: 2,
      vsync: this,
    );

    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final result = await LocationService.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        position = result;
      });
    } catch (_) {
      // Busca continua funcionando sem GPS.
    }
  }

  @override
  void dispose() {
    controller.dispose();
    debouncer.dispose();
    tabs.dispose();
    super.dispose();
  }

  double? _distance(
    Activity activity,
  ) {
    if (position == null) {
      return null;
    }

    if (activity.latitude == 0 && activity.longitude == 0) {
      return null;
    }

    return LocationService.distanceKm(
      fromLatitude: position!.latitude,
      fromLongitude: position!.longitude,
      toLatitude: activity.latitude,
      toLongitude: activity.longitude,
    );
  }

  bool _matchesDate(
    DateTime startsAt,
    SearchDateFilter filter,
  ) {
    if (filter == SearchDateFilter.any) {
      return true;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (filter == SearchDateFilter.today) {
      final tomorrow = today.add(
        const Duration(days: 1),
      );

      return !startsAt.isBefore(today) && startsAt.isBefore(tomorrow);
    }

    if (filter == SearchDateFilter.tomorrow) {
      final tomorrow = today.add(
        const Duration(days: 1),
      );

      final afterTomorrow = today.add(
        const Duration(days: 2),
      );

      return !startsAt.isBefore(tomorrow) &&
          startsAt.isBefore(
            afterTomorrow,
          );
    }

    var daysUntilSaturday = DateTime.saturday - now.weekday;

    if (daysUntilSaturday < 0) {
      daysUntilSaturday += 7;
    }

    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      daysUntilSaturday = DateTime.saturday - now.weekday;
    }

    final saturday = today.add(
      Duration(
        days: daysUntilSaturday,
      ),
    );

    final monday = saturday.add(
      const Duration(days: 2),
    );

    return !startsAt.isBefore(saturday) && startsAt.isBefore(monday);
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
      return snapshot.docs
          .map(Activity.fromFirestore)
          .where(
            (activity) =>
                activity.status == 'active' &&
                activity.startsAt.isAfter(
                  DateTime.now(),
                ),
          )
          .toList();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get peopleStream {
    return FirebaseFirestore.instance
        .collection('users')
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buscar',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(
              text: 'Atividades',
            ),
            Tab(
              text: 'Pessoas',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppSearchField(
              controller: controller,
              onChanged: (value) {
                debouncer.run(() {
                  if (!mounted) return;

                  setState(() {
                    query = value.trim();
                  });
                });
              },
              onFilter: () {
                context.push(
                  '/filters',
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                //
                // ATIVIDADES
                //
                StreamBuilder<List<Activity>>(
                  stream: activitiesStream,
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
                            'Erro ao buscar atividades:\n'
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    var activities = snapshot.data ?? <Activity>[];

                    final normalizedQuery = query.toLowerCase();

                    activities = activities.where((activity) {
                      if (normalizedQuery.isNotEmpty) {
                        final text = '${activity.title} '
                                '${activity.address} '
                                '${activity.category.label}'
                            .toLowerCase();

                        if (!text.contains(
                          normalizedQuery,
                        )) {
                          return false;
                        }
                      }

                      if (filters.categories.isNotEmpty) {
                        if (!filters.categories.contains(
                          activity.category,
                        )) {
                          return false;
                        }
                      }

                      if (!_matchesDate(
                        activity.startsAt,
                        filters.date,
                      )) {
                        return false;
                      }

                      if (filters.vacanciesOnly &&
                          activity.participantCount >=
                              activity.maxParticipants) {
                        return false;
                      }

                      final distance = _distance(
                        activity,
                      );

                      if (distance != null &&
                          distance > filters.maxDistanceKm) {
                        return false;
                      }

                      return true;
                    }).map(
                      (activity) {
                        final distance = _distance(
                          activity,
                        );

                        if (distance == null) {
                          return activity;
                        }

                        return activity.copyWith(
                          distanceKm: distance,
                        );
                      },
                    ).toList();

                    activities.sort(
                      (a, b) {
                        final distanceA = _distance(a);

                        final distanceB = _distance(b);

                        if (distanceA != null && distanceB != null) {
                          return distanceA.compareTo(
                            distanceB,
                          );
                        }

                        return a.startsAt.compareTo(
                          b.startsAt,
                        );
                      },
                    );

                    if (activities.isEmpty) {
                      return const AppEmptyState(
                        title: 'Nenhuma atividade encontrada',
                        message: 'Tente outro termo ou altere seus filtros.',
                        icon: Icons.search_off_rounded,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        24,
                      ),
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
                    );
                  },
                ),

                //
                // PESSOAS
                //
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: peopleStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erro ao buscar pessoas:\n'
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final currentUid = FirebaseAuth.instance.currentUser?.uid;

                    final normalizedQuery = query.toLowerCase();

                    final people =
                        (snapshot.data?.docs ?? []).where((document) {
                      if (document.id == currentUid) {
                        return false;
                      }

                      final data = document.data();

                      final name = (data['name'] ?? '').toString();

                      final city = (data['city'] ?? '').toString();

                      final username = (data['username'] ?? '').toString();

                      if (normalizedQuery.isEmpty) {
                        return true;
                      }

                      return '$name @$username $city'.toLowerCase().contains(
                            normalizedQuery,
                          );
                    }).toList();

                    if (people.isEmpty) {
                      return const AppEmptyState(
                        title: 'Nenhuma pessoa encontrada',
                        message: 'Tente pesquisar por outro nome ou cidade.',
                        icon: Icons.person_search_rounded,
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      itemCount: people.length,
                      itemBuilder: (context, index) {
                        final document = people[index];

                        final data = document.data();

                        final name = (data['name'] ?? 'Usuário').toString();

                        final city = (data['city'] ?? '').toString();

                        final username = (data['username'] ?? '').toString();

                        return SearchResultUser(
                          name: name,
                          city: [
                            if (username.isNotEmpty) '@$username',
                            if (city.isNotEmpty) city
                          ].join(' • '),
                          onTap: () {
                            context.push(
                              '/profile/user/${document.id}',
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
