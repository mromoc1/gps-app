import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'device_screen.dart';

/// Pestaña Vehículos: lista con el estado de cada vehículo.
/// Si el usuario tiene varios vehículos agrupados, aparecen filtros por grupo.
class VehiclesTab extends StatefulWidget {
  final Future<void> Function() onRefresh;
  const VehiclesTab({super.key, required this.onRefresh});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  int? _group; // null = todos

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehículos')),
      body: ListenableBuilder(
        listenable: api,
        builder: (context, _) {
          final all = api.devices.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (all.isEmpty) {
            return const CenteredMessage(
              icon: Icons.directions_car_outlined,
              text: 'Todavía no tienes vehículos asociados a tu cuenta.',
            );
          }
          // Grupos que realmente tienen vehículos de este usuario.
          final usedGroups = all.map((d) => d.groupId).where((g) => g != 0).toSet();
          final groups = api.groups.values
              .where((g) => usedGroups.contains(g.id))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          final showGroups = all.length > 1 && groups.isNotEmpty;
          final hasUngrouped = all.any((d) => d.groupId == 0);
          if (!showGroups) _group = null;
          final list = _group == null
              ? all
              : all.where((d) => d.groupId == _group).toList();

          return RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(12, 12, 12, navBarSpace(context)),
              children: [
                if (showGroups) ...[
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip('Todos (${all.length})', _group == null, () => setState(() => _group = null)),
                        for (final g in groups)
                          _chip(
                            '${g.name} (${all.where((d) => d.groupId == g.id).length})',
                            _group == g.id,
                            () => setState(() => _group = g.id),
                          ),
                        if (hasUngrouped)
                          _chip('Sin grupo', _group == 0, () => setState(() => _group = 0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                for (final d in list) ...[
                  DeviceCard(
                    device: d,
                    position: api.positions[d.id],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DeviceScreen(deviceId: d.id),
                    )),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}
