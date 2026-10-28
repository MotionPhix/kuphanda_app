import 'models/document.dart';

enum LibrarySort {
  recent('Recently added'),
  relevance('Best match'),
  rating('Top rated'),
  title('Title A–Z'),
  year('Newest paper');

  const LibrarySort(this.label);

  final String label;
}

enum AccessFilter {
  all('All access'),
  free('Free'),
  premium('Premium');

  const AccessFilter(this.label);

  final String label;
}

enum AvailabilityFilter {
  all('Everything'),
  offline('On this device'),
  saved('Saved'),
  guides('Study guides');

  const AvailabilityFilter(this.label);

  final String label;
}

/// Pure query object for the library. Keeping the matching rules out of the
/// widget tree makes them cheap to unit-test and impossible to drift between
/// the library, search suggestions and the assignment picker.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.subjectIds = const <String>{},
    this.forms = const <int>{},
    this.kinds = const <DocumentKind>{},
    this.availability = AvailabilityFilter.all,
    this.access = AccessFilter.all,
    this.sort = LibrarySort.recent,
    this.onlyFeatured = false,
  });

  final String search;
  final Set<String> subjectIds;
  final Set<int> forms;
  final Set<DocumentKind> kinds;
  final AvailabilityFilter availability;
  final AccessFilter access;
  final LibrarySort sort;
  final bool onlyFeatured;

  bool get hasFilters =>
      search.trim().isNotEmpty ||
      subjectIds.isNotEmpty ||
      forms.isNotEmpty ||
      kinds.isNotEmpty ||
      availability != AvailabilityFilter.all ||
      access != AccessFilter.all ||
      onlyFeatured;

  int get activeFilterCount =>
      (search.trim().isEmpty ? 0 : 1) +
      (subjectIds.isEmpty ? 0 : 1) +
      (forms.isEmpty ? 0 : 1) +
      (kinds.isEmpty ? 0 : 1) +
      (availability == AvailabilityFilter.all ? 0 : 1) +
      (access == AccessFilter.all ? 0 : 1) +
      (onlyFeatured ? 1 : 0);

  LibraryQuery copyWith({
    String? search,
    Set<String>? subjectIds,
    Set<int>? forms,
    Set<DocumentKind>? kinds,
    AvailabilityFilter? availability,
    AccessFilter? access,
    LibrarySort? sort,
    bool? onlyFeatured,
  }) {
    return LibraryQuery(
      search: search ?? this.search,
      subjectIds: subjectIds ?? this.subjectIds,
      forms: forms ?? this.forms,
      kinds: kinds ?? this.kinds,
      availability: availability ?? this.availability,
      access: access ?? this.access,
      sort: sort ?? this.sort,
      onlyFeatured: onlyFeatured ?? this.onlyFeatured,
    );
  }

  LibraryQuery cleared() => LibraryQuery(sort: sort);

  List<LibraryEntry> apply(List<LibraryEntry> entries) {
    final tokens = search
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    final filtered = entries.where((entry) {
      final document = entry.document;

      if (onlyFeatured && !document.featured) return false;
      if (subjectIds.isNotEmpty && !subjectIds.contains(document.subjectId)) return false;
      if (forms.isNotEmpty && !forms.contains(document.form)) return false;
      if (kinds.isNotEmpty && !kinds.contains(document.kind)) return false;
      if (access == AccessFilter.free && document.accessTier != AccessTier.free) {
        return false;
      }
      if (access == AccessFilter.premium && document.accessTier == AccessTier.free) {
        return false;
      }

      switch (availability) {
        case AvailabilityFilter.offline:
          if (!entry.onDevice) return false;
        case AvailabilityFilter.saved:
          if (!entry.saved) return false;
        case AvailabilityFilter.guides:
          if (document.guideId == null) return false;
        case AvailabilityFilter.all:
          break;
      }

      if (tokens.isEmpty) return true;

      final haystack = <String>[
        document.title,
        document.description,
        document.author,
        document.publisher ?? '',
        document.kind.label,
        document.qualification,
        entry.subject.name,
        entry.subject.shortName,
        if (document.year != null) '${document.year}',
        if (document.paperNumber != null) 'paper ${document.paperNumber}',
        ...document.tags,
      ].join(' ').toLowerCase();

      return tokens.every(haystack.contains);
    }).toList();

    int compare(LibraryEntry a, LibraryEntry b) {
      switch (sort) {
        case LibrarySort.recent:
          return b.document.addedAt.compareTo(a.document.addedAt);
        case LibrarySort.relevance:
          final featured = (b.document.featured ? 1 : 0) - (a.document.featured ? 1 : 0);
          if (featured != 0) return featured;
          final rating = b.document.rating.compareTo(a.document.rating);
          if (rating != 0) return rating;
          return b.document.ratingCount.compareTo(a.document.ratingCount);
        case LibrarySort.rating:
          final rating = b.document.rating.compareTo(a.document.rating);
          if (rating != 0) return rating;
          return b.document.ratingCount.compareTo(a.document.ratingCount);
        case LibrarySort.title:
          return a.document.title.toLowerCase().compareTo(b.document.title.toLowerCase());
        case LibrarySort.year:
          final year = (b.document.year ?? 0).compareTo(a.document.year ?? 0);
          if (year != 0) return year;
          return b.document.addedAt.compareTo(a.document.addedAt);
      }
    }

    filtered.sort(compare);
    return filtered;
  }
}
