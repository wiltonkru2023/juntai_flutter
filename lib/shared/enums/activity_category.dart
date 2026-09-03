import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

enum ActivityCategory { football, running, cycling, games, cinema, coffee, restaurant, gym, music, beach, hiking, study, pets, boardGames }

extension ActivityCategoryX on ActivityCategory {
  String get label => switch (this) {
    ActivityCategory.football => 'Futebol',
    ActivityCategory.running => 'Corrida',
    ActivityCategory.cycling => 'Pedalar',
    ActivityCategory.games => 'Games',
    ActivityCategory.cinema => 'Cinema',
    ActivityCategory.coffee => 'Café',
    ActivityCategory.restaurant => 'Restaurante',
    ActivityCategory.gym => 'Academia',
    ActivityCategory.music => 'Música',
    ActivityCategory.beach => 'Praia',
    ActivityCategory.hiking => 'Trilha',
    ActivityCategory.study => 'Estudos',
    ActivityCategory.pets => 'Pet',
    ActivityCategory.boardGames => 'Jogos de mesa',
  };

  IconData get icon => switch (this) {
    ActivityCategory.football => Icons.sports_soccer_rounded,
    ActivityCategory.running => Icons.directions_run_rounded,
    ActivityCategory.cycling => Icons.directions_bike_rounded,
    ActivityCategory.games => Icons.sports_esports_rounded,
    ActivityCategory.cinema => Icons.movie_rounded,
    ActivityCategory.coffee => Icons.local_cafe_rounded,
    ActivityCategory.restaurant => Icons.restaurant_rounded,
    ActivityCategory.gym => Icons.fitness_center_rounded,
    ActivityCategory.music => Icons.music_note_rounded,
    ActivityCategory.beach => Icons.beach_access_rounded,
    ActivityCategory.hiking => Icons.terrain_rounded,
    ActivityCategory.study => Icons.menu_book_rounded,
    ActivityCategory.pets => Icons.pets_rounded,
    ActivityCategory.boardGames => Icons.casino_rounded,
  };

  Color get color => switch (this) {
    ActivityCategory.running => AppColors.blue,
    ActivityCategory.games => AppColors.purple,
    ActivityCategory.cinema => AppColors.red,
    ActivityCategory.coffee || ActivityCategory.restaurant => AppColors.orange,
    _ => AppColors.primary,
  };
}
