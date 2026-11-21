import 'package:flutter/material.dart';

import '../api.dart';
import '../widgets.dart';
import 'device_screen.dart';

/// Pestaña Vehículos: lista con el estado de cada vehículo.
class VehiclesTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const VehiclesTab({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehículos')),
      body: ListenableBuilder(
        listenable: api,
        builder: (context, _) {
          final list = api.devices.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          if (list.isEmpty) {
            return const CenteredMessage(
              icon: Icons.directions_car_outlined,
              text: 'Todavía no tienes vehículos asociados a tu cuenta.',
            );
          }
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(12, 12, 12, navBarSpace(context)),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => DeviceCard(
                device: list[i],
                position: api.positions[list[i].id],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DeviceScreen(deviceId: list[i].id),
                )),
              ),
            ),
          );
        },
      ),
    );
  }
}
