class SharedQueryController {
  List<T> apply<T>({
    required List<T> items,
    String searchQuery = '',
    bool Function(T item, String normalizedQuery)? searchPredicate,
    bool Function(T item)? filterPredicate,
    int Function(T a, T b)? sortComparator,
    bool Function(T item)? pinToTopPredicate,
  }) {
    var result = List<T>.from(items);

    final normalized = searchQuery.trim().toLowerCase();
    if (normalized.isNotEmpty && searchPredicate != null) {
      result = result
          .where((item) => searchPredicate(item, normalized))
          .toList();
    }

    if (filterPredicate != null) {
      result = result.where(filterPredicate).toList();
    }

    if (sortComparator != null) {
      result.sort(sortComparator);
    }

    if (pinToTopPredicate != null) {
      final pinned = <T>[];
      final nonPinned = <T>[];
      for (final item in result) {
        if (pinToTopPredicate(item)) {
          pinned.add(item);
        } else {
          nonPinned.add(item);
        }
      }
      result = [...pinned, ...nonPinned];
    }

    return result;
  }

  Set<String> addFilter({
    required Set<String> selectedFilters,
    required String filter,
    required String allFilter,
  }) {
    final updated = Set<String>.from(selectedFilters);
    if (filter == allFilter) {
      return {allFilter};
    }
    updated.remove(allFilter);
    updated.add(filter);
    return updated.isEmpty ? {allFilter} : updated;
  }

  Set<String> removeFilter({
    required Set<String> selectedFilters,
    required String filter,
    required String allFilter,
  }) {
    final updated = Set<String>.from(selectedFilters)..remove(filter);
    return updated.isEmpty ? {allFilter} : updated;
  }
}
