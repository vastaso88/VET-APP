import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/auth.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../auth/data/auth_repository_factory.dart';
import '../../../auth/domain/auth_error_messages.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../auth/presentation/widgets/phone_number_field.dart';
import '../../data/profile_photo_repository.dart';
import '../widgets/account_page_scaffold.dart';
import '../widgets/profile_avatar.dart';
import 'change_email_page.dart';

/// "Il tuo profilo": name, surname, optional phone and photo. Stored in the
/// sign-in account's own metadata (no separate profile table): the data is
/// small, belongs to the account and goes away with it, and it is available
/// as soon as the owner is signed in.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final PhoneInputController _phone;
  final _photos = ProfilePhotoRepository();

  String? _avatarPath;
  Uint8List? _pickedPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = CurrentUser.get();
    final (first, last) = _splitName(user);
    _firstName = TextEditingController(text: first);
    _lastName = TextEditingController(text: last);
    _phone = PhoneInputController(initialStored: user?.phone);
    _avatarPath = user?.avatarPath;
  }

  /// Accounts created before the profile existed only have one display name:
  /// first word as the name, the rest as the surname.
  (String, String) _splitName(AppUser? user) {
    if (user == null) return ('', '');
    if (user.firstName != null || user.lastName != null) {
      return (user.firstName ?? '', user.lastName ?? '');
    }
    final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return ('', '');
    return (parts.first, parts.skip(1).join(' '));
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;
    try {
      setState(() {
        _pickedPhoto = ProfilePhotoRepository.prepare(bytes);
        _removePhoto = false;
      });
    } catch (_) {
      _snack(context.l10n.accountProfilePhotoFailed);
    }
  }

  void _clearPhoto() => setState(() {
        _pickedPhoto = null;
        _removePhoto = true;
      });

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final l10n = context.l10n;
    setState(() => _saving = true);

    var avatarPath = _avatarPath;
    try {
      final picked = _pickedPhoto;
      if (picked != null) {
        avatarPath = await _photos.upload(picked);
        if (avatarPath == null) {
          _fail(l10n.accountProfilePhotoFailed);
          return;
        }
      } else if (_removePhoto && avatarPath != null) {
        await _photos.remove(avatarPath);
        avatarPath = null;
      }
    } catch (_) {
      _fail(l10n.accountProfilePhotoFailed);
      return;
    }

    final result = await const AuthRepositoryFactory().create().updateProfile(
          ProfileUpdate(
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.e164,
            avatarPath: avatarPath,
          ),
        );
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        setState(() {
          _saving = false;
          _avatarPath = avatarPath;
          _pickedPhoto = null;
          _removePhoto = false;
        });
        _snack(l10n.accountProfileSaved);
        Navigator.of(context).maybePop();
      },
      onFailure: (error) => _fail(presentAuthError(error).message),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    _snack(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = CurrentUser.get();
    final letter = CurrentUser.firstName(fallback: 'O').substring(0, 1).toUpperCase();
    final hasPhoto = _pickedPhoto != null || (_avatarPath != null && !_removePhoto);

    return AccountPageScaffold(
      title: l10n.accountProfileTitle,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ProfileAvatar(
                letter: letter,
                avatarPath: _removePhoto ? null : _avatarPath,
                previewBytes: _pickedPhoto,
                size: 96,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _pickPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(
                    hasPhoto ? l10n.accountProfilePhotoChange : l10n.accountProfilePhotoAdd,
                  ),
                ),
                if (hasPhoto)
                  TextButton(
                    onPressed: _saving ? null : _clearPhoto,
                    child: Text(l10n.accountProfilePhotoRemove),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AuthInputField(
              controller: _firstName,
              label: l10n.accountProfileFirstName,
              hintText: '',
              autofillHints: const [AutofillHints.givenName],
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.accountProfileFirstNameRequired : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AuthInputField(
              controller: _lastName,
              label: l10n.accountProfileLastName,
              hintText: '',
              autofillHints: const [AutofillHints.familyName],
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? l10n.accountProfileLastNameRequired : null,
            ),
            const SizedBox(height: AppSpacing.md),
            PhoneNumberField(
              controller: _phone,
              label: l10n.accountProfilePhone,
              helperText: l10n.authPhoneHelp,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.accountProfileEmailLabel, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    user?.email ?? '',
                    style: AppTextStyles.body.copyWith(color: AppColors.text),
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const ChangeEmailPage()),
                          ),
                  child: Text(l10n.accountProfileEmailChange),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_save()),
              child: _saving ? const PetLoader.small() : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
