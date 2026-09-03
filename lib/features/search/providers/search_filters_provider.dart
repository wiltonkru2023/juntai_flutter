import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/enums/activity_category.dart';

enum SearchDateFilter {
  any,
  today,
  tomorrow,
  weekend,
}

class SearchFilters {
  const SearchFilters({
    this.categories = const <ActivityCategory>{},
    this.maxDistanceKm = 50,
    this.date = SearchDateFilter.any,
    this.vacanciesOnly = false,
  });

  final Set<ActivityCategory> categories;
  final double maxDistanceKm;
  final SearchDateFilter date;
  final bool vacanciesOnly;

  SearchFilters copyWith({
    Set<ActivityCategory>? categories,
    double? maxDistanceKm,
    SearchDateFilter? date,
    bool? vacanciesOnly,
  }) {
    return SearchFilters(
      categories: categories ?? this.categories,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      date: date ?? this.date,
      vacanciesOnly: vacanciesOnly ?? this.vacanciesOnly,
    );
  }
}

class SearchFiltersController extends StateNotifier<SearchFilters> {
  SearchFiltersController() : super(const SearchFilters());

  void apply(SearchFilters filters) {
    state = filters;
  }

  void clear() {
    state = const SearchFilters();
  }
}

final searchFiltersProvider =
    StateNotifierProvider<SearchFiltersController, SearchFilters>(
  (ref) => SearchFiltersController(),
);
