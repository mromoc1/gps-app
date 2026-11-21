import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../widgets.dart';
import 'alerts_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';
import 'vehicles_tab.dart';

/// Pantalla principal: mapa a pantalla completa y barra de navegación
/// flotante con las pestañas Mapa, Vehículos, Alertas y Perfil.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await api.loadAll();
      api.startLive();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudieron cargar los vehículos.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _goToMap() => setState(() => _tab = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          MapTab(loading: _loading, error: _error, onRetry: _load),
          VehiclesTab(onRefresh: _load),
          const AlertsTab(),
          ProfileTab(onShowMap: _goToMap),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FloatingNavBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadiusSheet),
          boxShadow: const [
            BoxShadow(
                blurRadius: 16, color: Colors.black26, offset: Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusSheet),
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: NavigationBar(
              height: kNavBarHeight,
              selectedIndex: index,
              onDestinationSelected: onChanged,
              backgroundColor: scheme.surface.withValues(alpha: 0.97),
              indicatorColor: scheme.primaryContainer,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Mapa',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_car_outlined),
                  selectedIcon: Icon(Icons.directions_car),
                  label: 'Vehículos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_none),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Alertas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
