/// The profile fields the owner can edit. A null or blank optional field
/// clears it.
class ProfileUpdate {
  const ProfileUpdate({
    required this.firstName,
    required this.lastName,
    this.phone,
    this.avatarPath,
  });

  final String firstName;
  final String lastName;
  final String? phone;
  final String? avatarPath;
}

/// What happened when the owner asked to change their email.
enum EmailChangeStatus {
  /// The account already carries the new address.
  applied,

  /// A confirmation link was sent to the new address; the old one still
  /// signs in until it is opened.
  confirmationSent,
}
