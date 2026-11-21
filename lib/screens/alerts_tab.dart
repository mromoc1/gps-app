import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Pestaña Alertas: eventos de todos los vehículos de los últimos días,
/// más los que llegan en vivo.
class AlertsTab extends StatefulWidget {
  const AlertsTab({super.key});

  @override
  State<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<AlertsTab> {
  static const int _days = 3;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  List<TEvent> _events = [];
  StreamSubscription<TEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = api.eventStream.listen((e) {
      if (!mounted) return;
      setState(() => _events.insert(0, e));
    });
    api.addListener(_maybeFirstLoad);
    _maybeFirstLoad();
  }

  @override
  void dispose() {
    _sub?.cancel();
    api.removeListener(_maybeFirstLoad);
    super.dispose();
  }

  void _maybeFirstLoad() {
    if (_loaded || _loading || api.devices.isEmpty) return;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: _days));
      final to = now.add(const Duration(minutes: 1));
      final all = <TEvent>[];
      for (final d in api.devices.values) {
        all.addAll(await api.events(d.id, from, to));
      }
      all.sort((a, b) => (b.eventTime ?? DateTime(0))
          .compareTo(a.eventTime ?? DateTime(0)));
      _events = all;
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading && _events.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _events.isEmpty) {
      body = CenteredMessage(
        icon: Icons.error_outline,
        text: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    } else if (_events.isEmpty) {
      body = const CenteredMessage(
        icon: Icons.notifications_none,
        text: 'Sin alertas en los últimos $_days días.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: navBarSpace(context)),
          itemCount: _events.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = _events[i];
            final c = eventColor(e.type);
            final name = api.devices[e.deviceId]?.name ?? '';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: c.withValues(alpha: 0.12),
                child: Icon(eventIcon(e.type), color: c),
              ),
              title: Text(eventLabel(e)),
              subtitle: Text(
                  [if (name.isNotEmpty) name, fmtDateTime(e.eventTime)]
                      .join(' · ')),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: body,
    );
  }
}
