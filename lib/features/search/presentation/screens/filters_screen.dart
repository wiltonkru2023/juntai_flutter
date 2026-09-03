import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../providers/search_filters_provider.dart';
import '../widgets/filter_chip.dart';

class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({
    super.key,
  });

  @override
  ConsumerState<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends ConsumerState<FiltersScreen> {
  final Set<ActivityCategory> categories = {};

  double distance = 50;

  bool vacanciesOnly = false;

  SearchDateFilter date = SearchDateFilter.any;

  bool initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (initialized) return;

    final current = ref.read(searchFiltersProvider);

    categories
      ..clear()
      ..addAll(current.categories);

    distance = current.maxDistanceKm;
    vacanciesOnly = current.vacanciesOnly;
    date = current.date;

    initialized = true;
  }

  void apply() {
    ref.read(searchFiltersProvider.notifier).apply(
          SearchFilters(
            categories: Set<ActivityCategory>.from(
              categories,
            ),
            maxDistanceKm: distance,
            date: date,
            vacanciesOnly: vacanciesOnly,
          ),
        );

    context.pop();
  }

  void clear() {
    setState(() {
      categories.clear();
      distance = 50;
      date = SearchDateFilter.any;
      vacanciesOnly = false;
    });

    ref.read(searchFiltersProvider.notifier).clear();
  }

  String dateLabel(
    SearchDateFilter value,
  ) {
    switch (value) {
      case SearchDateFilter.any:
        return 'Qualquer data';

      case SearchDateFilter.today:
        return 'Hoje';

      case SearchDateFilter.tomorrow:
        return 'Amanhã';

      case SearchDateFilter.weekend:
        return 'Fim de semana';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Filtros',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: clear,
            child: const Text(
              'Limpar',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Categoria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActivityCategory.values.map(
              (category) {
                return JuntaiFilterChip(
                  label: category.label,
                  selected: categories.contains(
                    category,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        categories.add(
                          category,
                        );
                      } else {
                        categories.remove(
                          category,
                        );
                      }
                    });
                  },
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 28),
          Text(
            'Distância: até ${distance.round()} km',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A distância é aplicada quando a localização do celular está disponível.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          Slider(
            value: distance,
            min: 1,
            max: 50,
            divisions: 49,
            label: '${distance.round()} km',
            onChanged: (value) {
              setState(() {
                distance = value;
              });
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Quando',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SearchDateFilter.values.map(
              (value) {
                return ChoiceChip(
                  label: Text(
                    dateLabel(value),
                  ),
                  selected: date == value,
                  onSelected: (_) {
                    setState(() {
                      date = value;
                    });
                  },
                );
              },
            ).toList(),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Somente com vagas',
            ),
            subtitle: const Text(
              'Oculta atividades que já estão lotadas.',
            ),
            value: vacanciesOnly,
            onChanged: (value) {
              setState(() {
                vacanciesOnly = value;
              });
            },
          ),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.lock_open_rounded,
            ),
            title: Text(
              'Busca pública',
            ),
            subtitle: Text(
              'A busca mostra atividades públicas. '
              'Atividades privadas ficam disponíveis apenas para participantes e organizadores.',
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Aplicar filtros',
            icon: Icons.check_rounded,
            onPressed: apply,
          ),
        ],
      ),
    );
  }
}
