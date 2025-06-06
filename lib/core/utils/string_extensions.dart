extension StringNullExtension on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}

