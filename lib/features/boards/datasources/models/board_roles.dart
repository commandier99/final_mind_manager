class BoardRoles {
  static const String manager = 'manager';
  static const String member = 'member';
  static const String supervisor = 'supervisor';

  static const Set<String> assignableRoles = {member, supervisor};
  static const Set<String> allRoles = {manager, member, supervisor};

  static String normalize(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case manager:
        return manager;
      case supervisor:
        return supervisor;
      case member:
      default:
        return member;
    }
  }

  static bool isAssignable(String? role) {
    return assignableRoles.contains(normalize(role));
  }
}
