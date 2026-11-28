import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../push.dart';
import '../widgets.dart';
import 'alerts_sheet.dart';
import 'map_tab.dart';
import 'profile_tab.dart';
import 'vehicles_sheet.dart';

/// Pantalla principal: mapa a pantalla completa y barra de navegación
/// flotante. Vehículos y Alertas suben como paneles sobre el mapa;
/// Perfil es una página.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _page = 0; // 0 = mapa, 1 = perfil
  int _nav = 0; // botón marcado en la barra (0 mapa, 1 vehículos, 2 alertas, 3 perfil)
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
      // Deja este celular listo para recibir alertas (pide permiso una vez).
      Push.register();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'No se pudieron cargar los vehículos.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _goToMap() => setState(() {
        _page = 0;
        _nav = 0;
      });

  Future<void> _onNav(int i) async {
    if (i == 0 || i == 3) {
      setState(() {
        _page = i == 0 ? 0 : 1;
        _nav = i;
      });
      return;
    }
    setState(() {
      _page = 0;
      _nav = i;
    });
    await showMapSheet(
      context,
      (controller) => i == 1
          ? VehiclesSheet(scrollController: controller, onRefresh: _load)
          : AlertsSheet(scrollController: controller),
    );
    if (mounted && _nav == i) setState(() => _nav = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _page,
        children: [
          MapTab(loading: _loading, error: _error, onRetry: _load),
          ProfileTab(onShowMap: _goToMap),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        index: _nav,
        onChanged: _onNav,
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
    // Barra azul de la marca: elegido en blanco, el resto en celeste.
    final navTheme = NavigationBarTheme.of(context).copyWith(
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Colors.white : kOnBlueMuted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Colors.white : kOnBlueMuted)),
    );
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
            child: NavigationBarTheme(
              data: navTheme,
              child: NavigationBar(
              height: kNavBarHeight,
              selectedIndex: index,
              onDestinationSelected: onChanged,
              backgroundColor: kBrandBlue,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.white.withValues(alpha: 0.22),
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
      ),
    );
  }
}
