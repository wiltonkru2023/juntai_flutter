extension StringX on String {
  String get initials => trim().isEmpty
      ? '?'
      : trim()
          .split(RegExp(r'\s+'))
          .take(2)
          .map((e) => e[0].toUpperCase())
          .join();
}
