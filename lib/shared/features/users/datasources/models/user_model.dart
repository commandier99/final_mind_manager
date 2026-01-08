import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  // Core identity
  final String userId;
  final String userEmail;
  final String userName;
  final String userHandle;

  // Profile
  final String? userProfilePicture;
  final String? userBio;
  final String? userPhoneNumber;
  final List<String> userSkills;

  // Visibility & status
  final bool userIsVerified;
  final bool userIsPublic;
  final bool userAllowSearch;
  final bool userIsActive;
  final bool userIsBanned;

  // Authentication & metadata
  final Timestamp? userCreatedAt;
  final Timestamp? userLastLogin;
  final Timestamp? userLastActiveAt;

  // Localization
  final String userLocale;
  final String userTimezone;

  const UserModel({
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userHandle,

    this.userProfilePicture,
    this.userBio,
    this.userPhoneNumber,
    this.userSkills = const [],

    this.userIsVerified = false,
    this.userIsPublic = false,
    this.userAllowSearch = false,
    this.userIsActive = true,
    this.userIsBanned = false,

    this.userCreatedAt,
    this.userLastLogin,
    this.userLastActiveAt,

    this.userLocale = 'en',
    this.userTimezone = 'UTC',
  });

  UserModel copyWith({
    String? userId,
    String? userEmail,
    String? userName,
    String? userHandle,

    String? userProfilePicture,
    String? userBio,
    String? userPhoneNumber,
    List<String>? userSkills,

    bool? userIsVerified,
    bool? userIsPublic,
    bool? userAllowSearch,
    bool? userIsActive,
    bool? userIsBanned,

    Timestamp? userCreatedAt,
    Timestamp? userLastLogin,
    Timestamp? userLastActiveAt,

    String? userLocale,
    String? userTimezone,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userHandle: userHandle ?? this.userHandle,

      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      userBio: userBio ?? this.userBio,
      userPhoneNumber: userPhoneNumber ?? this.userPhoneNumber,
      userSkills: userSkills ?? this.userSkills,

      userIsVerified: userIsVerified ?? this.userIsVerified,
      userIsPublic: userIsPublic ?? this.userIsPublic,
      userAllowSearch: userAllowSearch ?? this.userAllowSearch,
      userIsActive: userIsActive ?? this.userIsActive,
      userIsBanned: userIsBanned ?? this.userIsBanned,

      userCreatedAt: userCreatedAt ?? this.userCreatedAt,
      userLastLogin: userLastLogin ?? this.userLastLogin,
      userLastActiveAt: userLastActiveAt ?? this.userLastActiveAt,

      userLocale: userLocale ?? this.userLocale,
      userTimezone: userTimezone ?? this.userTimezone,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      userId: id,
      userEmail: map['userEmail'] ?? '',
      userName: map['userName'] ?? '',
      userHandle: map['userHandle'] ?? '',

      userProfilePicture: map['userProfilePicture'],
      userBio: map['userBio'],
      userPhoneNumber: map['userPhoneNumber'],
      userSkills:
          map['userSkills'] != null ? List<String>.from(map['userSkills']) : [],

      userIsVerified: map['userIsVerified'] ?? false,
      userIsPublic: map['userIsPublic'] ?? false,
      userAllowSearch: map['userAllowSearch'] ?? true,
      userIsActive: map['userIsActive'] ?? true,
      userIsBanned: map['userIsBanned'] ?? false,

      userCreatedAt: map['userCreatedAt'],
      userLastLogin: map['userLastLogin'],
      userLastActiveAt: map['userLastActiveAt'],

      userLocale: map['userLocale'] ?? 'en',
      userTimezone: map['userTimezone'] ?? 'UTC',
    );
  }

  Map<String, dynamic> toMap({bool isCreating = false}) {
    return {
      'userEmail': userEmail,
      'userName': userName,
      'userHandle': userHandle,

      'userProfilePicture': userProfilePicture,
      'userBio': userBio,
      'userPhoneNumber': userPhoneNumber,
      'userSkills': userSkills,

      'userIsVerified': userIsVerified,
      'userIsPublic': userIsPublic,
      'userAllowSearch': userAllowSearch,
      'userIsActive': userIsActive,
      'userIsBanned': userIsBanned,

      'userCreatedAt':
          isCreating ? FieldValue.serverTimestamp() : userCreatedAt,
      'userLastLogin': userLastLogin,
      'userLastActiveAt': userLastActiveAt,

      'userLocale': userLocale,
      'userTimezone': userTimezone,
    };
  }
}
