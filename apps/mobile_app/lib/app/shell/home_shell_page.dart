import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import '../../features/pets/pets.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  late int _currentIndex = widget.initialIndex;

  late final List<_ShellTabNavigator> _pages = const [
    _ShellTabNavigator(rootPage: HomeDashboardPage()),
    _ShellTabNavigator(rootPage: PetsListPage()),
    _ShellTabNavigator(rootPage: SettingsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
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
    );
  }

  void _handleDestinationSelected(int value) {
    setState(() {
      _currentIndex = value;
    });
  }

  List<NavigationRailDestination> get _destinations => const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.pets_outlined),
          selectedIcon: Icon(Icons.pets_rounded),
          label: Text('Animali'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: Text('Impostazioni'),
        ),
      ];

  List<NavigationDestination> get _bottomDestinations => const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.pets_outlined),
          selectedIcon: Icon(Icons.pets_rounded),
          label: 'Animali',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Impostazioni',
        ),
      ];
}

class _ShellTabNavigator extends StatefulWidget {
  const _ShellTabNavigator({
    required this.rootPage,
  });

  final Widget rootPage;

  @override
  State<_ShellTabNavigator> createState() => _ShellTabNavigatorState();
}

class _ShellTabNavigatorState extends State<_ShellTabNavigator> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (_) {
        return MaterialPageRoute<void>(
          builder: (_) => widget.rootPage,
        );
      },
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
        'Warm clinical workspace',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFCEE0D8),
            ),
      ),
    );
  }
}
