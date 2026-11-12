class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.displayName,
    this.onboardingCompleted = false,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarPath,
  });

  final String id;
  final String email;
  final String? displayName;
  final DateTime createdAt;
  final bool onboardingCompleted;

  /// Profile fields the owner edits in "Il tuo profilo" (kept in the sign-in
  /// account's metadata). [displayName] is "firstName lastName" once set.
  final String? firstName;
  final String? lastName;
  final String? phone;

  /// Storage path of the profile photo in the private `pet-photos` bucket.
  final String? avatarPath;

  /// Same user with every profile field replaced exactly (a null clears it,
  /// unlike [copyWith]).
  AppUser withProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarPath,
  }) {
    final name = [firstName, lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    return AppUser(
      id: id,
      email: email,
      displayName: name.isEmpty ? displayName : name,
      createdAt: createdAt,
      onboardingCompleted: onboardingCompleted,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      avatarPath: avatarPath,
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    DateTime? createdAt,
    bool? onboardingCompleted,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      avatarPath: avatarPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'onboarding_completed': onboardingCompleted,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'avatar_path': avatarPath,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['display_name'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      onboardingCompleted: map['onboarding_completed'] as bool? ?? false,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
    );
  }
}
