import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/shell/home_shell_page.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../../shared/widgets/coming_soon_page.dart';
import '../../../account_consents/data/account_consents_remote_data_source.dart';
import '../../../account_consents/domain/account_consent_models.dart';
import '../../../auth/data/auth_repository_factory.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../billing/data/billing_demo_store.dart';
import '../../../language/presentation/widgets/language_settings_section.dart';
import '../../../location/data/address_geocoder.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/data/location_repository.dart';
import '../../../location/domain/coordinates.dart';
import '../../../notifications/application/notification_scheduler.dart';
import '../../../notifications/data/notification_preferences_store.dart';
import '../../../nearby_places/data/radar_places_repository.dart';
import '../../../nearby_places/data/reverse_geocoder.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/widgets/medical_record_consent_card.dart';
import '../../../account/presentation/pages/change_email_page.dart';
import '../../../account/presentation/pages/change_password_page.dart';
import '../../../account/presentation/pages/delete_account_page.dart';
import '../../../../app/launch/restorable_pages.dart';
import '../../../../app/launch/warm_start_store.dart';
import '../../../account/presentation/widgets/profile_avatar.dart';
import '../../data/gallery_save_settings_store.dart';
import '../../data/layout_settings_store.dart';
import '../../data/unit_settings_store.dart';
import '../../domain/unit_system.dart';
import '../../../auth/presentation/pages/legal_text_page.dart';
import '../widgets/collapsible_section.dart';
import 'location_picker_page.dart';
import '../../../../l10n/regional_defaults.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;

  final _consentsDataSource = HttpAccountConsentsRemoteDataSource();
  AccountConsentsSnapshot? _consents;
  bool _loadingConsents = true;
  String? _consentsError;

  bool _capturingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadConsents();
    unawaited(LayoutSettingsStore.instance.ensureLoaded());
    unawaited(GallerySaveSettingsStore.instance.ensureLoaded());
    unawaited(_restoreOpenSection());
    unawaited(_loadLocation());
    unawaited(_loadSupportContact());
    unawaited(_loadAppVersion());
    unawaited(_loadNotificationPermission());
    unawaited(BillingDemoStore.instance.syncFromBackend());
    if (HomeShellNavigation.consumeLocationScroll()) {
      _openSection = 'localita';
    }
    HomeShellNavigation.locationScrollRequests.addListener(_scrollToLocation);
  }

  @override
  void dispose() {
    HomeShellNavigation.locationScrollRequests.removeListener(_scrollToLocation);
    super.dispose();
  }

  /// Accordion: at most one section is open, and all start closed.
  String? _openSection;

  void _toggleSection(String id) {
    setState(() => _openSection = _openSection == id ? null : id);
    // Remembered so a restart (app killed in the background) reopens it.
    unawaited(const WarmStartStore().saveDraft(_openSectionDraftKey, _openSection ?? ''));
  }

  static const _openSectionDraftKey = 'settings.open_section';

  Future<void> _restoreOpenSection() async {
    final id = await const WarmStartStore().loadDraft(_openSectionDraftKey);
    if (mounted && _openSection == null && id != null && id.isNotEmpty) {
      setState(() => _openSection = id);
    }
  }

  void _openFullPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalTextPage(
          consentKey: AccountConsentKeys.privacyPolicy,
          title: context.l10n.settingsPrivacyPolicyFullTitle,
          shareable: true,
        ),
      ),
    );
  }

  /// From "Scegli un indirizzo": open Località; the section scrolls itself
  /// into view when it expands.
  void _scrollToLocation() {
    if (!mounted) return;
    HomeShellNavigation.consumeLocationScroll();
    setState(() => _openSection = 'localita');
  }

  Future<void> _loadNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (mounted) setState(() => _notifications = status.isGranted);
    } catch (_) {}
  }

  Future<void> _setNotifications(bool value) async {
    if (!value) {
      // The OS only lets the owner revoke a notification permission from its
      // own settings, so send them there rather than pretending it's off.
      await openAppSettings();
      return;
    }
    try {
      final status = await Permission.notification.request();
      if (mounted) setState(() => _notifications = status.isGranted);
    } catch (_) {}
    NotificationScheduler.instance.requestResync();
  }

  String _shortPlaceLabel(String label) {
    final parts = label.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty);
    return parts.take(3).join(', ');
  }

  String? _supportContactEmail;

  Future<void> _loadSupportContact() async {
    final info = await RadarPlacesRepository().loadSources();
    if (mounted) {
      setState(() => _supportContactEmail = info.supportContactEmail);
    }
  }

  void _updateLayout(LayoutSettings settings) {
    unawaited(LayoutSettingsStore.instance.update(settings));
  }

  /// LocationPreferenceStore (shared_preferences) is the fast local cache;
  /// the `user_locations` table is the cross-device source of truth, so on
  /// open we let a successful remote fetch overwrite the local copy.
  Future<void> _loadLocation() async {
    await LocationPreferenceStore.instance.ensureLoaded();
    final remote = await LocationRepository().loadRemote(resolveCurrentOwnerId());
    if (remote != null) {
      await LocationPreferenceStore.instance.update(remote);
    }
    unawaited(_migrateLegacyHomeLabel());
  }

  /// Residences saved before compactAddressLabel() existed still carry
  /// Nominatim's full display_name (lots of comma-separated segments:
  /// street, neighborhood, municipio, city, province, region, country...).
  /// Re-derive a short label for those, once, so the owner doesn't have to
  /// re-set their address by hand.
  Future<void> _migrateLegacyHomeLabel() async {
    final preference = LocationPreferenceStore.instance.preference;
    final home = preference.home;
    final label = preference.homeLabel;
    if (home == null || label == null || !_looksLikeLegacyLongLabel(label)) return;

    final shortened = await ReverseGeocoder().addressOf(home);
    if (shortened == null || shortened == label) return;
    _updateLocation(preference.copyWith(homeLabel: shortened));
  }

  bool _looksLikeLegacyLongLabel(String label) => isLegacyLongAddressLabel(label);

  void _updateLocation(UserLocationPreference preference) {
    unawaited(LocationPreferenceStore.instance.update(preference));
    unawaited(LocationRepository().saveRemote(resolveCurrentOwnerId(), preference));
  }

  Future<void> _captureCurrentPosition() async {
    if (_capturingLocation) return;
    setState(() {
      _capturingLocation = true;
      _locationError = null;
    });
    final result = await const GeolocatorLocationSampler().requestCurrentPosition();
    if (!mounted) return;
    setState(() => _capturingLocation = false);
    if (!result.isSuccess) {
      setState(() => _locationError = _locationErrorMessage(result.failure!));
      return;
    }
    final preference = LocationPreferenceStore.instance.preference;
    _updateLocation(
      preference.copyWith(
        current: result.coordinates,
        currentLabel: 'Posizione GPS', // valore salvato: sempre italiano
        currentSource: LocationSource.deviceGps,
        currentCapturedAt: DateTime.now(),
      ),
    );
  }

  String _locationErrorMessage(LocationRequestFailure failure) {
    switch (failure) {
      case LocationRequestFailure.permissionDenied:
      case LocationRequestFailure.permissionDeniedForever:
        return context.l10n.settingsLocationErrorPermissionDenied;
      case LocationRequestFailure.serviceDisabled:
        return context.l10n.settingsLocationErrorServiceDisabled;
      case LocationRequestFailure.timeout:
        return context.l10n.settingsLocationErrorTimeout;
      case LocationRequestFailure.unsupported:
        return context.l10n.settingsLocationErrorUnsupported;
    }
  }

  String _formatCoordinates(Coordinates coordinates) =>
      '${coordinates.latitude.toStringAsFixed(3)}, ${coordinates.longitude.toStringAsFixed(3)}';

  Future<void> _showSetHomeLocationDialog(UserLocationPreference preference) async {
    final result = await showDialog<GeocodedAddress>(
      context: context,
      builder: (_) => const _HomeAddressDialog(),
    );
    if (result == null) return;
    _updateLocation(preference.copyWith(home: result.coordinates, homeLabel: result.displayLabel));
  }

  Future<void> _loadConsents() async {
    setState(() {
      _loadingConsents = true;
      _consentsError = null;
    });
    final result = await _consentsDataSource.fetch();
    if (!mounted) return;
    result.fold(
      onSuccess: (snapshot) => setState(() {
        _consents = snapshot;
        _loadingConsents = false;
      }),
      onFailure: (error) => setState(() {
        _consentsError = error.message;
        _loadingConsents = false;
      }),
    );
  }

  Future<void> _setConsent(String key, bool granted) async {
    final previous = _consents;
    // Optimistic flip so the toggle feels immediate; reverted below on failure.
    if (previous != null) {
      setState(() {
        _consents = AccountConsentsSnapshot(
          decisions: {
            ...previous.decisions,
            key: ConsentDecision(granted: granted, version: '', decidedAt: DateTime.now()),
          },
          catalog: previous.catalog,
        );
      });
    }
    final result = await _consentsDataSource.setConsent(consentKey: key, granted: granted);
    if (!mounted) return;
    result.fold(
      onSuccess: (snapshot) => setState(() => _consents = snapshot),
      onFailure: (error) {
        setState(() => _consents = previous);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(restorableRoute<void>('profile_edit'));
    if (mounted) setState(() {});
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  String _appVersion = '';

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  /// Opens the mail app with the support address, a subject and the app
  /// version already filled in. The address comes from the backend
  /// (SUPPORT_CONTACT_EMAIL).
  Future<void> _contactSupport() async {
    final l10n = context.l10n;
    final email = _supportContactEmail;
    if (email == null) {
      _showInfoDialog(l10n.settingsAccountSupport, l10n.settingsContactUnavailable);
      return;
    }
    final version = _appVersion.isEmpty ? '?' : _appVersion;
    final uri = Uri.parse(
      'mailto:$email'
      '?subject=${Uri.encodeComponent(l10n.accountSupportSubject(version))}'
      '&body=${Uri.encodeComponent(l10n.accountSupportBody(version))}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (!opened && mounted) {
      _showInfoDialog(l10n.settingsAccountSupport, l10n.settingsContactWriteTo(email));
    }
  }

  void _openBilling() {
    Navigator.of(context).push(restorableRoute<void>('billing'));
  }

  void _openDataSources() {
    Navigator.of(context).push(restorableRoute<void>('data_sources'));
  }

  void _openHelpCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComingSoonPage(
          title: context.l10n.settingsHelpCenterTitle,
          icon: Icons.help_outline_rounded,
          description: context.l10n.settingsHelpCenterComingSoon,
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String body, {VoidCallback? onConfirm}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
        content: Text(body, style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonClose),
          ),
          if (onConfirm != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              child: Text(context.l10n.commonConfirm),
            ),
        ],
      ),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsRateAppThanks)),
    );
  }

  void _logout() {
    _showInfoDialog(
      context.l10n.settingsLogout,
      context.l10n.settingsLogoutConfirmBody,
      onConfirm: () => unawaited(_performLogout()),
    );
  }

  Future<void> _performLogout() async {
    final result = await const AuthRepositoryFactory().create().signOut();
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        // No reminders or pet names left on the phone after logout.
        unawaited(NotificationScheduler.instance.clearAll());
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil(AppRouter.auth, (route) => false);
      },
      onFailure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      ),
    );
  }

  List<Widget> _buildConsentRows() {
    if (_loadingConsents) {
      return [
        _Row(
          icon: Icons.hourglass_empty_rounded,
          iconColor: AppColors.mutedText,
          title: context.l10n.commonLoading,
        ),
      ];
    }
    if (_consentsError != null) {
      return [
        _Row(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.danger,
          title: context.l10n.settingsConsentsUnavailable,
          subtitle: context.l10n.settingsConsentsTapToRetry,
          onTap: _loadConsents,
        ),
      ];
    }

    final consents = _consents!;
    return [
      _buildMandatoryConsentRow(
        key: AccountConsentKeys.termsOfService,
        title: context.l10n.settingsConsentTerms,
        icon: Icons.description_outlined,
      ),
      _buildMandatoryConsentRow(
        key: AccountConsentKeys.privacyPolicy,
        title: context.l10n.settingsConsentPrivacy,
        icon: Icons.shield_outlined,
      ),
      _ToggleRow(
        icon: Icons.mail_outline_rounded,
        iconColor: AppColors.accent,
        title: context.l10n.settingsConsentMarketingEmail,
        value: consents.decisions[AccountConsentKeys.marketingEmail]?.granted ?? false,
        onChanged: (value) => _setConsent(AccountConsentKeys.marketingEmail, value),
      ),
      _ToggleRow(
        icon: Icons.insights_outlined,
        iconColor: AppColors.info,
        title: context.l10n.settingsConsentAnalytics,
        value: consents.decisions[AccountConsentKeys.analytics]?.granted ?? false,
        onChanged: (value) => _setConsent(AccountConsentKeys.analytics, value),
      ),
      ValueListenableBuilder<int>(
        valueListenable: PetDemoStore.changes,
        builder: (context, _, __) => _PetClinicalConsentSection(
          pets: PetDemoStore.instance.list().where((pet) => !pet.isMemorial).toList(),
        ),
      ),
    ];
  }

  Widget _buildMandatoryConsentRow({
    required String key,
    required String title,
    required IconData icon,
  }) {
    final consents = _consents!;
    final decision = consents.decisions[key];
    final entry = consents.catalog[key];
    final text = entry?.text ?? '';

    return _Row(
      icon: icon,
      iconColor: AppColors.mutedText,
      title: title,
      subtitle: decision != null
          ? context.l10n.settingsConsentAccepted(
              decision.version,
              _numericDate(decision.decidedAt),
            )
          : context.l10n.settingsConsentToConfirm,
      onTap: () => _showInfoDialog(
        title,
        text,
        onConfirm: decision == null ? () => _setConsent(key, true) : null,
      ),
    );
  }

  String _numericDate(DateTime date) =>
      formatAppDate(date, appNumericDatePattern(context.l10n.settingsNumericDatePattern));

  String _capitalized(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.get();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            LayoutSettingsStore.instance,
            LocationPreferenceStore.instance,
            GallerySaveSettingsStore.instance,
          ]),
          builder: (context, _) {
            final layout = LayoutSettingsStore.instance.settings;
            final location = LocationPreferenceStore.instance.preference;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xxxl,
              ),
              children: [
                Text(context.l10n.settingsTitle, style: AppTextStyles.display.copyWith(fontSize: 28)),
                const SizedBox(height: AppSpacing.xl),
                _Row(
                  leading: ProfileAvatar(
                    letter: CurrentUser.firstName(fallback: context.l10n.settingsGuestInitial)
                        .substring(0, 1)
                        .toUpperCase(),
                    avatarPath: user?.avatarPath,
                  ),
                  title: CurrentUser.fullName(fallback: context.l10n.settingsGuestName),
                  subtitle: user?.email ?? context.l10n.settingsNoActiveSession,
                  onTap: _openProfile,
                ),
                CollapsibleSection(
                  sectionId: 'abbonamento',
                  expanded: _openSection == 'abbonamento',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionSubscription,
                  children: [
                    ListenableBuilder(
                      listenable: BillingDemoStore.instance,
                      builder: (context, _) => _Row(
                        icon: Icons.workspace_premium_outlined,
                        iconColor: AppColors.accent,
                        title: context.l10n.settingsSubscriptionAndPayments,
                        trailingText: BillingDemoStore.instance.isOnTrial
                            ? context.l10n.settingsTrialExpiresOn(
                                _numericDate(BillingDemoStore.instance.trialEndsAt!),
                              )
                            : BillingDemoStore.instance.currentPlan.displayName,
                        onTap: _openBilling,
                      ),
                    ),
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'notifiche',
                  expanded: _openSection == 'notifiche',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionPushNotifications,
                  children: [
                    _ToggleRow(
                      icon: Icons.notifications_active_outlined,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsNotificationsToggle,
                      value: _notifications,
                      onChanged: (value) => unawaited(_setNotifications(value)),
                    ),
                    // The browser can't receive scheduled notifications.
                    if (!kIsWeb) const _NotificationCategoryToggles(),
                  ],
                ),
                LanguageSettingsSection(
                  expanded: _openSection == LanguageSettingsSection.sectionId,
                  onToggle: _toggleSection,
                ),
                CollapsibleSection(
                  sectionId: 'layout',
                  expanded: _openSection == 'layout',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionLayout,
                  children: [
                    _StepperRow(
                      icon: Icons.view_week_outlined,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsLayoutWeeksTitle,
                      subtitle: context.l10n.settingsLayoutWeeksSubtitle,
                      value: layout.weeksShown,
                      minValue: 1,
                      maxValue: 4,
                      onChanged: (value) => _updateLayout(layout.copyWith(weeksShown: value)),
                    ),
                    _ChoiceRow(
                      icon: Icons.calendar_view_week_outlined,
                      iconColor: AppColors.info,
                      title: context.l10n.settingsLayoutWeekStartTitle,
                      leftLabel: _capitalized(appLongWeekdaysMondayFirst()[0]),
                      rightLabel: _capitalized(appLongWeekdaysMondayFirst()[6]),
                      isLeftSelected: layout.weekStartDay == WeekStartDay.monday,
                      onSelectLeft: () =>
                          _updateLayout(layout.copyWith(weekStartDay: WeekStartDay.monday)),
                      onSelectRight: () =>
                          _updateLayout(layout.copyWith(weekStartDay: WeekStartDay.sunday)),
                    ),
                    _OptionsRow<ChatTextSize>(
                      icon: Icons.text_fields_rounded,
                      iconColor: AppColors.accent,
                      title: context.l10n.settingsLayoutChatTextSizeTitle,
                      options: [
                        for (final size in ChatTextSize.values) (value: size, label: size.label),
                      ],
                      selected: layout.chatTextSize,
                      onSelected: (size) => _updateLayout(layout.copyWith(chatTextSize: size)),
                      preview: Text(
                        context.l10n.settingsLayoutChatTextSizePreview,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize:
                              (AppTextStyles.bodySmall.fontSize ?? 14) * layout.chatTextSize.scale,
                        ),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: UnitSettingsStore.instance,
                      builder: (context, _) => _OptionsRow<UnitSystem>(
                        icon: Icons.straighten_rounded,
                        iconColor: AppColors.info,
                        title: context.l10n.settingsLayoutUnitsTitle,
                        options: [
                          for (final system in UnitSystem.values)
                            (value: system, label: system.label),
                        ],
                        selected: UnitSettingsStore.instance.system,
                        onSelected: (system) =>
                            unawaited(UnitSettingsStore.instance.setSystem(system)),
                        preview: Text(
                          UnitSettingsStore.instance.system.description,
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'foto_e_video',
                  expanded: _openSection == 'foto_e_video',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionPhotosVideos,
                  children: [
                    _ToggleRow(
                      icon: Icons.photo_library_outlined,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsGallerySaveTitle,
                      subtitle: context.l10n.settingsGallerySaveSubtitle,
                      value: GallerySaveSettingsStore.instance.enabled,
                      onChanged: (value) =>
                          unawaited(GallerySaveSettingsStore.instance.setEnabled(value)),
                    ),
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'localita',
                  expanded: _openSection == 'localita',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionLocation,
                  children: [
                    Text(
                      context.l10n.settingsLocationIntro,
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ChoiceRow(
                      icon: Icons.my_location_outlined,
                      iconColor: AppColors.info,
                      title: context.l10n.settingsLocationReferenceTitle,
                      leftLabel: context.l10n.settingsLocationModeCurrent,
                      rightLabel: context.l10n.settingsLocationModeHome,
                      isLeftSelected: location.mode == LocationMode.currentPosition,
                      onSelectLeft: () =>
                          _updateLocation(location.copyWith(mode: LocationMode.currentPosition)),
                      onSelectRight: () =>
                          _updateLocation(location.copyWith(mode: LocationMode.homeResidence)),
                    ),
                    _Row(
                      icon: Icons.gps_fixed_rounded,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsLocationCurrentTitle,
                      subtitle: _capturingLocation
                          ? context.l10n.settingsLocationDetecting
                          : location.current != null
                              ? _formatCoordinates(location.current!)
                              : context.l10n.settingsLocationCurrentNotSet,
                      trailingText: _capturingLocation ? null : context.l10n.settingsLocationRefresh,
                      onTap: _captureCurrentPosition,
                    ),
                    _Row(
                      icon: Icons.home_outlined,
                      iconColor: AppColors.accent,
                      title: context.l10n.settingsLocationHomeTitle,
                      subtitle: location.home != null
                          ? _shortPlaceLabel(
                              location.homeLabel ?? _formatCoordinates(location.home!))
                          : context.l10n.settingsLocationHomeNotSet,
                      trailingText: location.home != null ? context.l10n.commonEdit : context.l10n.settingsLocationSet,
                      onTap: () => _showSetHomeLocationDialog(location),
                    ),
                    if (_locationError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(_locationError!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                    ],
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'permessi',
                  expanded: _openSection == 'permessi',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionPermissions,
                  children: [
                    ..._buildConsentRows(),
                    _Row(
                      icon: Icons.description_outlined,
                      iconColor: AppColors.info,
                      title: context.l10n.settingsPrivacyPolicyFullTitle,
                      subtitle: context.l10n.settingsPrivacyPolicyFullSubtitle,
                      onTap: _openFullPrivacyPolicy,
                    ),
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'assistenza',
                  expanded: _openSection == 'assistenza',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionSupport,
                  children: [
                    _Row(
                      icon: Icons.help_outline_rounded,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsHelpCenterTitle,
                      onTap: _openHelpCenter,
                    ),
                    _Row(
                      icon: Icons.mail_outline_rounded,
                      iconColor: AppColors.accent,
                      title: context.l10n.settingsContactUs,
                      // The address comes from the backend (SUPPORT_CONTACT_EMAIL):
                      // none is shown until it is known, rather than a hardcoded
                      // one on a domain that may not be ours.
                      subtitle: _supportContactEmail,
                      onTap: () => unawaited(_contactSupport()),
                    ),
                    _Row(
                      icon: Icons.star_outline_rounded,
                      iconColor: AppColors.warning,
                      title: context.l10n.settingsRateApp,
                      onTap: _rateApp,
                    ),
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'info',
                  expanded: _openSection == 'info',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionInfo,
                  children: [
                    _Row(
                      icon: Icons.dataset_outlined,
                      iconColor: AppColors.info,
                      title: context.l10n.settingsDataSourcesTitle,
                      subtitle: context.l10n.settingsDataSourcesSubtitle,
                      onTap: _openDataSources,
                    ),
                    _Row(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.mutedText,
                      title: context.l10n.settingsAppVersion,
                      trailingText: _appVersion.isEmpty ? null : _appVersion,
                    ),
                  ],
                ),
                CollapsibleSection(
                  sectionId: 'account',
                  expanded: _openSection == 'account',
                  onToggle: _toggleSection,
                  title: context.l10n.settingsSectionAccount,
                  children: [
                    _Row(
                      icon: Icons.person_outline_rounded,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsAccountProfile,
                      onTap: _openProfile,
                    ),
                    _Row(
                      icon: Icons.alternate_email_rounded,
                      iconColor: AppColors.info,
                      title: context.l10n.settingsAccountChangeEmail,
                      onTap: () => _openPage(const ChangeEmailPage()),
                    ),
                    _Row(
                      icon: Icons.lock_outline_rounded,
                      iconColor: AppColors.accent,
                      title: context.l10n.settingsAccountChangePassword,
                      onTap: () => _openPage(const ChangePasswordPage()),
                    ),
                    _Row(
                      icon: Icons.support_agent_rounded,
                      iconColor: AppColors.primary,
                      title: context.l10n.settingsAccountSupport,
                      subtitle: context.l10n.settingsAccountSupportSubtitle,
                      onTap: () => unawaited(_contactSupport()),
                    ),
                    _Row(
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.danger,
                      title: context.l10n.settingsLogout,
                      titleColor: AppColors.danger,
                      onTap: _logout,
                    ),
                    _Row(
                      icon: Icons.delete_forever_outlined,
                      iconColor: AppColors.danger,
                      title: context.l10n.settingsAccountDelete,
                      subtitle: context.l10n.settingsAccountDeleteSubtitle,
                      titleColor: AppColors.danger,
                      onTap: () => _openPage(const DeleteAccountPage()),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One switch per active pet: whether the chat may read that pet's clinical
/// records. Same decision and PUT as the switch in the pet's Referti tab.
class _PetClinicalConsentSection extends StatelessWidget {
  const _PetClinicalConsentSection({required this.pets});

  final List<PetProfile> pets;

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(context.l10n.settingsClinicalConsentSection),
        for (final pet in pets)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: MedicalRecordConsentCard(
              key: ValueKey('settings-consent-${pet.id}'),
              pet: pet,
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(letterSpacing: 0.8),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    this.leading,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailingText,
    this.onTap,
  });

  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveLeading = leading ??
        (icon != null ? _IconBadge(icon: icon!, color: iconColor ?? AppColors.primary) : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (effectiveLeading != null) ...[
                effectiveLeading,
                const SizedBox(width: AppSpacing.md)
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(
                        color: titleColor ?? AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                Text(trailingText!, style: AppTextStyles.bodySmall),
                if (onTap != null) const SizedBox(width: AppSpacing.xs),
              ],
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) Text(subtitle!, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Which kinds of notification arrive on the phone; stored on the phone
/// and followed at once by NotificationScheduler.
class _NotificationCategoryToggles extends StatelessWidget {
  const _NotificationCategoryToggles();

  @override
  Widget build(BuildContext context) {
    final store = NotificationPreferencesStore.instance;
    unawaited(store.ensureLoaded());
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final preferences = store.preferences;
        return Column(
          children: [
            _ToggleRow(
              icon: Icons.event_available_outlined,
              iconColor: AppColors.success,
              title: context.l10n.notificationsCategoryReminders,
              value: preferences.reminders,
              onChanged: (value) => unawaited(store.update(preferences.copyWith(reminders: value))),
            ),
            _ToggleRow(
              icon: Icons.medication_outlined,
              iconColor: AppColors.info,
              title: context.l10n.notificationsCategoryMedicines,
              value: preferences.medicines,
              onChanged: (value) => unawaited(store.update(preferences.copyWith(medicines: value))),
            ),
            _ToggleRow(
              icon: Icons.cake_outlined,
              iconColor: AppColors.accent,
              title: context.l10n.notificationsCategoryBirthdays,
              value: preferences.birthdays,
              onChanged: (value) => unawaited(store.update(preferences.copyWith(birthdays: value))),
            ),
          ],
        );
      },
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: value > minValue ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$value',
            style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
          IconButton(
            onPressed: value < maxValue ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onSelectLeft,
    required this.onSelectRight,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onSelectLeft;
  final VoidCallback onSelectRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _IconBadge(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
          _ChoicePill(label: leftLabel, selected: isLeftSelected, onTap: onSelectLeft),
          const SizedBox(width: AppSpacing.xs),
          _ChoicePill(label: rightLabel, selected: !isLeftSelected, onTap: onSelectRight),
        ],
      ),
    );
  }
}

/// A titled row with any number of mutually exclusive pills and an optional
/// preview line underneath (used when two choices are not enough).
class _OptionsRow<T> extends StatelessWidget {
  const _OptionsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.preview,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: icon, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in options)
                _ChoicePill(
                  label: option.label,
                  selected: option.value == selected,
                  onTap: () => onSelected(option.value),
                ),
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: AppSpacing.sm),
            preview!,
          ],
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeAddressDialog extends StatefulWidget {
  // ignore: unused_element_parameter
  const _HomeAddressDialog({this.geocoder});

  /// Injectable for widget tests (not yet exercised); defaults to the real
  /// Nominatim lookup, same pattern as CreateListingPage's locationSampler.
  final AddressGeocoder? geocoder;

  @override
  State<_HomeAddressDialog> createState() => _HomeAddressDialogState();
}

class _HomeAddressDialogState extends State<_HomeAddressDialog> {
  late final AddressGeocoder _geocoder = widget.geocoder ?? NominatimAddressGeocoder();
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: appHomeCountryDefault());

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _streetController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await _geocoder.geocode(
      street: _streetController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      city: _cityController.text.trim(),
      country: _countryController.text.trim(),
    );
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _submitting = false;
        _error = context.l10n.settingsHomeAddressNotFound;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  Future<void> _pickOnMap() async {
    final current = LocationPreferenceStore.instance.preference;
    final result = await Navigator.of(context).push<GeocodedAddress>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialPosition: current.home ??
              current.current ??
              Coordinates(
                latitude: appRegionalFormat().mapLatitude,
                longitude: appRegionalFormat().mapLongitude,
              ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final format = appRegionalFormat();
    final postalCodeField = TextFormField(
      controller: _postalCodeController,
      keyboardType: format.postalCodeNumeric ? TextInputType.number : TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: context.l10n.settingsHomeAddressPostalCode,
        hintText: format.postalCodeExample,
      ),
      validator: (value) => _required(value, context.l10n.settingsHomeAddressPostalCodeRequired),
    );
    final cityField = TextFormField(
      controller: _cityController,
      decoration: InputDecoration(labelText: context.l10n.settingsHomeAddressCity),
      validator: (value) => _required(value, context.l10n.settingsHomeAddressCityRequired),
    );
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
      title: Text(context.l10n.settingsLocationHomeTitle, style: AppTextStyles.title.copyWith(fontSize: 17)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickOnMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: Text(context.l10n.settingsLocationPickerTitle),
                style: OutlinedButton.styleFrom(minimumSize: Size.zero),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(context.l10n.settingsHomeAddressOrType, style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _streetController,
                decoration: InputDecoration(labelText: context.l10n.settingsHomeAddressStreet),
                validator: (value) =>
                    _required(value, context.l10n.settingsHomeAddressStreetRequired),
              ),
              const SizedBox(height: AppSpacing.md),
              // Germany/France/Spain/Italy/... write "10115 Berlin"; UK, US and
              // Australia write the city first and the code last.
              ...(format.postalCodeBeforeCity
                  ? [postalCodeField, const SizedBox(height: AppSpacing.md), cityField]
                  : [cityField, const SizedBox(height: AppSpacing.md), postalCodeField]),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _countryController,
                decoration: InputDecoration(labelText: context.l10n.settingsHomeAddressCountry),
                validator: (value) =>
                    _required(value, context.l10n.settingsHomeAddressCountryRequired),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: Text(
            _submitting ? context.l10n.settingsHomeAddressSearching : context.l10n.commonSave,
          ),
        ),
      ],
    );
  }
}
