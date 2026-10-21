import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../features/activities/presentation/pages/activities_page.dart';
import '../../features/billing/data/subscription_remote_data_source.dart';
import '../../features/billing/presentation/trial_countdown_dialog.dart';
import '../../features/dog_walks/data/active_walk_controller.dart';
import '../../features/dog_walks/data/active_walk_recovery_store.dart';
import '../../features/dog_walks/data/dog_walks_repository.dart';
import '../../features/dog_walks/data/home_widget_action_store.dart';
import '../../features/dog_walks/domain/walk_session.dart';
import '../../features/dog_walks/presentation/walk_labels.dart';
import '../../features/dog_walks/presentation/widgets/walk_control_sheet.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import '../../features/pets/data/pet_demo_store.dart';
import '../../features/pets/pets.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../l10n/l10n.dart';
import '../launch/route_restoration.dart';
import '../launch/warm_start_store.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  late int _currentIndex = widget.initialIndex;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  late final List<_ShellTabNavigator> _pages = [
    _ShellTabNavigator(
        tab: 0, navigatorKey: _navigatorKeys[0], rootPage: const HomeDashboardPage()),
    _ShellTabNavigator(
        tab: 1, navigatorKey: _navigatorKeys[1], rootPage: const PetsListPage()),
    _ShellTabNavigator(
        tab: 2, navigatorKey: _navigatorKeys[2], rootPage: const ActivitiesPage()),
    _ShellTabNavigator(
        tab: 3, navigatorKey: _navigatorKeys[3], rootPage: const SettingsPage()),
  ];

  @override
  void initState() {
    super.initState();
    HomeShellNavigation._requests.addListener(_onTabRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreOpenPages());
      // The shell being up means signed in and past splash/paywall: only now
      // may a tapped home-screen widget shortcut (reminder / walk) be opened,
      // and after the interrupted-walk prompt, so the two never stack.
      _checkForInterruptedWalk().whenComplete(() {
        if (!mounted) return;
        HomeWidgetActionStore.instance.shellReady();
        unawaited(_maybeShowTrialCountdown());
      });
    });
  }

  @override
  void dispose() {
    HomeShellNavigation._requests.removeListener(_onTabRequested);
    HomeWidgetActionStore.instance.shellGone();
    super.dispose();
  }

  /// After the app was killed in the background: opens again the pages that
  /// were open inside the tabs (pet, chat, records...), then starts saving the
  /// stack again. Once per run.
  Future<void> _restoreOpenPages() async {
    final restoration = RouteRestoration.instance;
    if (restoration.planConsumed) {
      // A rebuilt shell in the same run: nothing to reopen.
      _restoreDone.complete();
      return;
    }
    restoration.planConsumed = true;
    try {
      final plan = await restoration.loadPlan();
      if (plan.isEmpty || !mounted) return;
      // The walk page waits until the interrupted walk has been resumed (the
      // owner answers a dialog first); see _checkForInterruptedWalk.
      _deferredWalkPages = [for (final entry in plan) if (entry.kind == 'active_walk') entry];
      await _replay([for (final entry in plan) if (entry.kind != 'active_walk') entry]);
    } finally {
      _restoreDone.complete();
      restoration.enablePersistence();
    }
  }

  final Completer<void> _restoreDone = Completer<void>();
  List<RestorableRouteEntry> _deferredWalkPages = const [];

  Future<void> _replay(List<RestorableRouteEntry> plan) {
    return RouteReplayer(pages: RestorablePages.instance).replay(
      plan: plan,
      navigatorFor: (tab) =>
          tab >= 0 && tab < _navigatorKeys.length ? _navigatorKeys[tab].currentState : null,
      isAlive: () => mounted,
    );
  }

  Future<void> _maybeShowTrialCountdown() async {
    final result = await HttpSubscriptionRemoteDataSource().fetchStatus();
    if (!mounted) return;
    result.fold(
      onSuccess: (status) => showTrialCountdownIfDue(context, status),
      onFailure: (_) {},
    );
  }

  /// Offers to resume a walk that was still "in_progress" on disk when the
  /// app last closed - meaning the process was killed rather than the walk
  /// being stopped normally (owner report, 2026-09-29). Skipped if a walk
  /// is already active in this run (e.g. the shell rebuilt without the app
  /// actually restarting).
  Future<void> _checkForInterruptedWalk() async {
    if (ActiveWalkController.instance.isActive) return;

    final recovered = await const ActiveWalkRecoveryStore().load();
    if (recovered == null || !mounted) return;

    final shouldResume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.shellInterruptedWalkTitle),
        content: Text(
          context.l10n.shellInterruptedWalkBody(walkDistanceLabel(recovered.distanceMeters)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.shellInterruptedWalkDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.shellInterruptedWalkResume),
          ),
        ],
      ),
    );

    if (shouldResume == true) {
      await ActiveWalkController.instance.recoverInterrupted(recovered);
      // The walk page was open when the app died: put it back on the walk.
      await _restoreDone.future;
      if (mounted && _deferredWalkPages.isNotEmpty) {
        final pages = _deferredWalkPages;
        _deferredWalkPages = const [];
        await _replay(pages);
      }
    } else {
      await DogWalksRepository()
          .saveWalk(recovered.copyWith(status: WalkStatus.discarded));
      await const ActiveWalkRecoveryStore().clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Each tab keeps its own nested Navigator (see _ShellTabNavigator), so
    // the system back gesture — which only ever reaches the ROOT
    // Navigator — used to find nothing to pop and closed the app straight
    // from a pushed page like a pet's detail view. This intercepts it and
    // routes it to whichever navigation actually applies: the active tab's
    // own stack first, then back to the Home tab from any other tab, and
    // only lets the app close once already on Home with nothing pushed.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const _ActiveWalkBanner(),
              Expanded(child: _buildTabsArea(context)),
            ],
          ),
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return const SizedBox.shrink();
            }

            return NavigationBar(
              height: 76,
              backgroundColor: Colors.white,
              indicatorColor: AppColors.accentSoft,
              selectedIndex: _currentIndex,
              onDestinationSelected: _handleDestinationSelected,
              destinations: _bottomDestinations,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabsArea(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 900;
        final isExtendedRail = constraints.maxWidth >= 1240;

        if (isCompact) {
          return IndexedStack(
            index: _currentIndex,
            children: _pages,
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  NavigationRail(
                    extended: isExtendedRail,
                    minExtendedWidth: 228,
                    backgroundColor: AppColors.primary,
                    indicatorColor: AppColors.accentSoft,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _handleDestinationSelected,
                    labelType: isExtendedRail
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.selected,
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: Color(0xFFE7EEE9),
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                      child: _ShellBrand(extended: isExtendedRail),
                    ),
                    trailing: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                      child: _RailFooter(extended: isExtendedRail),
                    ),
                    destinations: _destinations,
                  ),
                  Expanded(
                    child: ClipRect(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _pages,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSystemBack() async {
    final activeNavigator = _navigatorKeys[_currentIndex].currentState;
    if (activeNavigator != null && activeNavigator.canPop()) {
      activeNavigator.pop();
      return;
    }

    if (_currentIndex != 0) {
      _handleDestinationSelected(0);
      return;
    }

    // Already on the Home tab with nothing pushed above it: this is the
    // true root, so leave the app rather than trapping the back button here.
    // On Android it goes to the background (as Android 12+ does by default)
    // instead of finishing: finishing killed the Flutter engine, and with it
    // any walk being tracked (owner report, 2026-10-07).
    if (await _moveAppToBackground()) return;
    SystemNavigator.pop();
  }

  static const _appNavigationChannel = MethodChannel('vetapp/app_navigation');

  Future<bool> _moveAppToBackground() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _appNavigationChannel.invokeMethod<bool>('moveToBackground') ?? false;
    } catch (_) {
      return false;
    }
  }

  void _onTabRequested() {
    final request = HomeShellNavigation._requests.value;
    if (request == null || !mounted) return;
    _handleDestinationSelected(request.tab);
  }

  void _handleDestinationSelected(int value) {
    // Always reset the tapped tab's own navigation stack to its root page,
    // whether it's already selected (re-tap resets it) or we're switching
    // into it from elsewhere (so stale nested navigation, e.g. a pet detail
    // page left open, never lingers behind the bottom nav / rail button).
    _navigatorKeys[value].currentState?.popUntil((route) => route.isFirst);
    setState(() {
      _currentIndex = value;
    });
    // So the next launch can reopen this tab (see WarmStartStore).
    unawaited(const WarmStartStore().saveTab(value));
  }

  List<NavigationRailDestination> get _destinations => [
        NavigationRailDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: Text(context.l10n.shellTabHome),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.pets_outlined),
          selectedIcon: const Icon(Icons.pets_rounded),
          label: Text(context.l10n.shellTabPets),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore_rounded),
          label: Text(context.l10n.shellTabActivities),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: Text(context.l10n.shellTabSettings),
        ),
      ];

  List<NavigationDestination> get _bottomDestinations => [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: context.l10n.shellTabHome,
        ),
        NavigationDestination(
          icon: const Icon(Icons.pets_outlined),
          selectedIcon: const Icon(Icons.pets_rounded),
          label: context.l10n.shellTabPets,
        ),
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore_rounded),
          label: context.l10n.shellTabActivities,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings_rounded),
          label: context.l10n.shellTabSettings,
        ),
      ];
}

class _ShellTabNavigator extends StatelessWidget {
  const _ShellTabNavigator({
    required this.tab,
    required this.navigatorKey,
    required this.rootPage,
  });

  final int tab;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget rootPage;

  @override
  Widget build(BuildContext context) {
    // The scope tells pages pushed in this tab which tab they belong to, so
    // they can be restored there (see RouteRestoration).
    return ShellTabScope(
      index: tab,
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) {
          return MaterialPageRoute<void>(
            builder: (_) => rootPage,
          );
        },
      ),
    );
  }
}

class _ShellBrand extends StatelessWidget {
  const _ShellBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.pets_rounded,
            color: AppColors.onPrimary,
          ),
        ),
        if (extended) ...[
          const SizedBox(width: 12),
          const SizedBox(
            width: 132,
            child: Text(
              'VET APP',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        context.l10n.shellRailFooter,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFCEE0D8),
            ),
      ),
    );
  }
}

/// Shown above the tab content whenever a walk is tracking in the
/// background (owner report, 2026-09-29: leaving the page used to lose the
/// walk - now it keeps running via ActiveWalkController.instance, and this
/// is the reminder that it's still going, wherever else the owner has
/// navigated). Ticks its own timer only while a walk is active, so it
/// isn't a wasted rebuild the rest of the time.
class _ActiveWalkBanner extends StatefulWidget {
  const _ActiveWalkBanner();

  @override
  State<_ActiveWalkBanner> createState() => _ActiveWalkBannerState();
}

class _ActiveWalkBannerState extends State<_ActiveWalkBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ActiveWalkController.instance.isActive) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _openWalkControls(WalkSession walk) async {
    await PetDemoStore.instance.ensureHydrated();
    PetProfile? pet;
    for (final candidate in PetDemoStore.instance.list()) {
      if (candidate.id == walk.petId) {
        pet = candidate;
        break;
      }
    }
    if (pet == null || !mounted) return;
    await showWalkControlSheet(context, pet: pet);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ActiveWalkController.instance,
      builder: (context, _) {
        final walk = ActiveWalkController.instance.walk;
        if (walk == null || walk.status != WalkStatus.inProgress) {
          return const SizedBox.shrink();
        }

        final activeSeconds = walkActiveDurationSeconds(walk);
        final label = walk.isPaused
            ? context.l10n.shellWalkPausedBanner(walkDistanceLabel(walk.distanceMeters))
            : context.l10n.shellWalkActiveBanner(
                walkElapsedLabel(activeSeconds),
                walkDistanceLabel(walk.distanceMeters),
              );
        return Material(
          color: AppColors.primary,
          child: InkWell(
            onTap: () => _openWalkControls(walk),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    walk.isPaused ? Icons.pause_circle_outline : Icons.directions_walk_rounded,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.onPrimary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lets any page switch the bottom navigation to another tab, so a screen of
/// another tab (e.g. Impostazioni) is opened as itself and the bar highlights
/// it, instead of being pushed on top of the tab the owner came from.
class HomeShellNavigation {
  const HomeShellNavigation._();

  static const homeTab = 0;
  static const petsTab = 1;
  static const activitiesTab = 2;
  static const settingsTab = 3;

  static final ValueNotifier<_TabRequest?> _requests = ValueNotifier<_TabRequest?>(null);

  /// Switches to [tab] and shows its root page. A new request object each
  /// time, so asking for the same tab twice still notifies.
  static void goToTab(int tab) => _requests.value = _TabRequest(tab);

  static bool _pendingLocationScroll = false;
  static final ValueNotifier<int> _locationScrollRequests = ValueNotifier<int>(0);

  /// Opens the Impostazioni tab already scrolled to the Località section.
  static void showSettingsLocation() {
    _pendingLocationScroll = true;
    _locationScrollRequests.value++;
    goToTab(settingsTab);
  }

  /// True once per [showSettingsLocation] request, for a Settings page built
  /// after the request was made.
  static bool consumeLocationScroll() {
    final pending = _pendingLocationScroll;
    _pendingLocationScroll = false;
    return pending;
  }

  /// Fires on each [showSettingsLocation], for a Settings page already built.
  static ValueListenable<int> get locationScrollRequests => _locationScrollRequests;
}

class _TabRequest {
  const _TabRequest(this.tab);

  final int tab;
}
