import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../../shared/widgets/coming_soon_page.dart';
import '../../../account_consents/data/account_consents_remote_data_source.dart';
import '../../../account_consents/domain/account_consent_models.dart';
import '../../../billing/data/billing_demo_store.dart';
import '../../../billing/presentation/pages/billing_page.dart';
import '../../../location/data/address_geocoder.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/data/location_repository.dart';
import '../../../location/domain/coordinates.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../data/layout_settings_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _activityReminders = true;
  String _weightUnit = 'kg';

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
    unawaited(_loadLocation());
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
  }

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
        currentLabel: 'Posizione GPS',
        currentSource: LocationSource.deviceGps,
        currentCapturedAt: DateTime.now(),
      ),
    );
  }

  String _locationErrorMessage(LocationRequestFailure failure) {
    switch (failure) {
      case LocationRequestFailure.permissionDenied:
      case LocationRequestFailure.permissionDeniedForever:
        return 'Permesso di localizzazione negato: abilitalo dalle impostazioni del dispositivo per usare la posizione attuale.';
      case LocationRequestFailure.serviceDisabled:
        return 'La localizzazione è disattivata sul dispositivo.';
      case LocationRequestFailure.timeout:
        return 'Non sono riuscito a rilevare la posizione in tempo, riprova.';
      case LocationRequestFailure.unsupported:
        return 'Localizzazione non disponibile su questo dispositivo/browser.';
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

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  void _openBilling() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BillingPage()),
    );
  }

  void _openHelpCenter() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ComingSoonPage(
          title: 'Centro assistenza',
          icon: Icons.help_outline_rounded,
          description: 'Domande frequenti e guide rapide, presto disponibili direttamente qui.',
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
            child: const Text('Chiudi'),
          ),
          if (onConfirm != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              child: const Text('Conferma'),
            ),
        ],
      ),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grazie per il supporto! ⭐')),
    );
  }

  void _logout() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logout non ancora collegato al flusso account.')),
    );
  }

  List<Widget> _buildConsentRows() {
    if (_loadingConsents) {
      return const [
        _Row(
          icon: Icons.hourglass_empty_rounded,
          iconColor: AppColors.mutedText,
          title: 'Caricamento…',
        ),
      ];
    }
    if (_consentsError != null) {
      return [
        _Row(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.danger,
          title: 'Non disponibili al momento',
          subtitle: 'Tocca per riprovare',
          onTap: _loadConsents,
        ),
      ];
    }

    final consents = _consents!;
    return [
      _buildMandatoryConsentRow(
        key: AccountConsentKeys.termsOfService,
        title: 'Termini di servizio',
        icon: Icons.description_outlined,
      ),
      _buildMandatoryConsentRow(
        key: AccountConsentKeys.privacyPolicy,
        title: 'Informativa privacy',
        icon: Icons.shield_outlined,
      ),
      _ToggleRow(
        icon: Icons.mail_outline_rounded,
        iconColor: AppColors.accent,
        title: 'Email di marketing',
        value: consents.decisions[AccountConsentKeys.marketingEmail]?.granted ?? false,
        onChanged: (value) => _setConsent(AccountConsentKeys.marketingEmail, value),
      ),
      _ToggleRow(
        icon: Icons.insights_outlined,
        iconColor: AppColors.info,
        title: "Analisi d'uso",
        value: consents.decisions[AccountConsentKeys.analytics]?.granted ?? false,
        onChanged: (value) => _setConsent(AccountConsentKeys.analytics, value),
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
          ? 'Accettati v${decision.version} il ${DateFormat('dd/MM/yyyy').format(decision.decidedAt)}'
          : 'Da confermare',
      onTap: () => _showInfoDialog(
        title,
        text,
        onConfirm: decision == null ? () => _setConsent(key, true) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = CurrentUser.get();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([LayoutSettingsStore.instance, LocationPreferenceStore.instance]),
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
            Text('Impostazioni', style: AppTextStyles.display.copyWith(fontSize: 28)),
            const SizedBox(height: AppSpacing.xl),
            _Row(
              leading: _Avatar(letter: CurrentUser.firstName(fallback: 'O').substring(0, 1).toUpperCase()),
              title: CurrentUser.fullName(fallback: 'Ospite'),
              subtitle: user?.email ?? 'Nessuna sessione attiva',
              onTap: _openProfile,
            ),
            const _SectionLabel('Abbonamento'),
            ListenableBuilder(
              listenable: BillingDemoStore.instance,
              builder: (context, _) => _Row(
                icon: Icons.workspace_premium_outlined,
                iconColor: AppColors.accent,
                title: 'Abbonamento e pagamenti',
                trailingText: BillingDemoStore.instance.currentPlan.displayName,
                onTap: _openBilling,
              ),
            ),
            const _SectionLabel('Preferenze'),
            _ToggleRow(
              icon: Icons.notifications_active_outlined,
              iconColor: AppColors.primary,
              title: 'Notifiche push',
              value: _notifications,
              onChanged: (value) => setState(() => _notifications = value),
            ),
            _ToggleRow(
              icon: Icons.event_available_outlined,
              iconColor: AppColors.success,
              title: 'Promemoria attività',
              value: _activityReminders,
              onChanged: (value) => setState(() => _activityReminders = value),
            ),
            _UnitRow(
              value: _weightUnit,
              onChanged: (value) => setState(() => _weightUnit = value),
            ),
            const _SectionLabel('Layout'),
            _StepperRow(
              icon: Icons.view_week_outlined,
              iconColor: AppColors.primary,
              title: 'Settimane visualizzate in Home',
              subtitle: 'Quante settimane mostrare nel calendario della Home.',
              value: layout.weeksShown,
              minValue: 1,
              maxValue: 4,
              onChanged: (value) => _updateLayout(layout.copyWith(weeksShown: value)),
            ),
            _ChoiceRow(
              icon: Icons.calendar_view_week_outlined,
              iconColor: AppColors.info,
              title: 'Inizio settimana',
              leftLabel: 'Lunedì',
              rightLabel: 'Domenica',
              isLeftSelected: layout.weekStartDay == WeekStartDay.monday,
              onSelectLeft: () => _updateLayout(layout.copyWith(weekStartDay: WeekStartDay.monday)),
              onSelectRight: () => _updateLayout(layout.copyWith(weekStartDay: WeekStartDay.sunday)),
            ),
            _ChoiceRow(
              icon: Icons.density_medium_outlined,
              iconColor: AppColors.accent,
              title: 'Densità liste',
              leftLabel: 'Comoda',
              rightLabel: 'Compatta',
              isLeftSelected: layout.listDensity == ListDensity.comfortable,
              onSelectLeft: () => _updateLayout(layout.copyWith(listDensity: ListDensity.comfortable)),
              onSelectRight: () => _updateLayout(layout.copyWith(listDensity: ListDensity.compact)),
            ),
            const _SectionLabel('Località'),
            Text(
              'Usata per personalizzare eventi e news in base alla zona.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChoiceRow(
              icon: Icons.my_location_outlined,
              iconColor: AppColors.info,
              title: 'Posizione di riferimento',
              leftLabel: 'Attuale',
              rightLabel: 'Residenza',
              isLeftSelected: location.mode == LocationMode.currentPosition,
              onSelectLeft: () => _updateLocation(location.copyWith(mode: LocationMode.currentPosition)),
              onSelectRight: () => _updateLocation(location.copyWith(mode: LocationMode.homeResidence)),
            ),
            _Row(
              icon: Icons.gps_fixed_rounded,
              iconColor: AppColors.primary,
              title: 'Posizione attuale',
              subtitle: _capturingLocation
                  ? 'Rilevamento in corso…'
                  : location.current != null
                      ? _formatCoordinates(location.current!)
                      : 'Non ancora impostata',
              trailingText: _capturingLocation ? null : 'Aggiorna',
              onTap: _captureCurrentPosition,
            ),
            _Row(
              icon: Icons.home_outlined,
              iconColor: AppColors.accent,
              title: 'Residenza abituale',
              subtitle: location.home != null
                  ? (location.homeLabel ?? _formatCoordinates(location.home!))
                  : 'Non impostata',
              trailingText: 'Imposta',
              onTap: () => _showSetHomeLocationDialog(location),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_locationError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
            ],
            const _SectionLabel('Permessi e consensi'),
            ..._buildConsentRows(),
            const _SectionLabel('Assistenza'),
            _Row(
              icon: Icons.help_outline_rounded,
              iconColor: AppColors.primary,
              title: 'Centro assistenza',
              onTap: _openHelpCenter,
            ),
            _Row(
              icon: Icons.mail_outline_rounded,
              iconColor: AppColors.accent,
              title: 'Contattaci',
              subtitle: 'supporto@vetapp.it',
              onTap: () => _showInfoDialog(
                'Contattaci',
                'Scrivi a supporto@vetapp.it per qualsiasi domanda: rispondiamo di solito entro un giorno lavorativo.',
              ),
            ),
            _Row(
              icon: Icons.star_outline_rounded,
              iconColor: AppColors.warning,
              title: "Valuta l'app",
              onTap: _rateApp,
            ),
            const _SectionLabel('Info'),
            const _Row(
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.mutedText,
              title: 'Versione app',
              trailingText: '1.0.0',
            ),
            const _SectionLabel('Account'),
            _Row(
              icon: Icons.logout_rounded,
              iconColor: AppColors.danger,
              title: 'Esci',
              titleColor: AppColors.danger,
              onTap: _logout,
            ),
          ],
            );
          },
        ),
      ),
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
    final effectiveLeading = leading ?? (icon != null ? _IconBadge(icon: icon!, color: iconColor ?? AppColors.primary) : null);

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
              if (effectiveLeading != null) ...[effectiveLeading, const SizedBox(width: AppSpacing.md)],
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
  });

  final IconData icon;
  final Color iconColor;
  final String title;
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
            child: Text(
              title,
              style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  const _UnitRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const _IconBadge(icon: Icons.scale_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Unità di misura',
              style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
            ),
          ),
          _UnitToggleButton(label: 'kg', selected: value == 'kg', onTap: () => onChanged('kg')),
          const SizedBox(width: AppSpacing.xs),
          _UnitToggleButton(label: 'lb', selected: value == 'lb', onTap: () => onChanged('lb')),
        ],
      ),
    );
  }
}

class _UnitToggleButton extends StatelessWidget {
  const _UnitToggleButton({required this.label, required this.selected, required this.onTap});

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
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 6),
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
                  style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
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
              style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
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
  final _countryController = TextEditingController(text: 'Italia');

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
        _error = 'Non trovo questo indirizzo. Controlla i dati e riprova.';
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
      title: Text('Residenza abituale', style: AppTextStyles.title.copyWith(fontSize: 17)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Indirizzo'),
                validator: (value) => _required(value, "Inserisci l'indirizzo"),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _postalCodeController,
                decoration: const InputDecoration(labelText: 'CAP'),
                validator: (value) => _required(value, 'Inserisci il CAP'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Città'),
                validator: (value) => _required(value, 'Inserisci la città'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'Nazione'),
                validator: (value) => _required(value, 'Inserisci la nazione'),
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
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Ricerca…' : 'Salva'),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primaryStrong,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: AppTextStyles.title.copyWith(color: AppColors.onPrimary, fontSize: 16),
        ),
      ),
    );
  }
}
