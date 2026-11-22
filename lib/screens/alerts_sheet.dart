import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Panel Alertas: sube sobre el mapa con los eventos de todos los vehículos
/// de los últimos días, más los que llegan en vivo.
class AlertsSheet extends StatefulWidget {
  final ScrollController scrollController;
  const AlertsSheet({super.key, required this.scrollController});

  @override
  State<AlertsSheet> createState() => _AlertsSheetState();
}

class _AlertsSheetState extends State<AlertsSheet> {
  static const int _days = 3;
  // Se guardan entre aperturas para mostrarlas al instante.
  static List<TEvent> _cache = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  List<TEvent> _events = List.of(_cache);
  StreamSubscription<TEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = api.eventStream.listen((e) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, e);
        _cache = List.of(_events);
      });
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
      _cache = List.of(all);
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final header = SheetHeader(
      title: 'Alertas',
      subtitle: 'Últimos $_days días',
      trailing: _loading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
    );
    final List<Widget> items;
    if (_loading && _events.isEmpty) {
      items = const [
        Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
      ];
    } else if (_error != null && _events.isEmpty) {
      items = [
        CenteredMessage(
          icon: Icons.error_outline,
          text: _error!,
          actionLabel: 'Reintentar',
          onAction: _load,
        ),
      ];
    } else if (_events.isEmpty) {
      items = const [
        CenteredMessage(
          icon: Icons.notifications_none,
          text: 'Sin alertas en los últimos $_days días.',
        ),
      ];
    } else {
      items = [
        for (var i = 0; i < _events.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _tile(_events[i]),
        ],
      ];
    }
    return ListView(
      controller: widget.scrollController,
      padding: EdgeInsets.only(bottom: 16 + MediaQuery.of(context).padding.bottom),
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: header),
        ...items,
      ],
    );
  }

  Widget _tile(TEvent e) {
    final c = eventColor(e.type);
    final name = api.devices[e.deviceId]?.name ?? '';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: c.withValues(alpha: 0.12),
        child: Icon(eventIcon(e.type), color: c),
      ),
      title: Text(eventLabel(e)),
      subtitle: Text([if (name.isNotEmpty) name, fmtDateTime(e.eventTime)].join(' · ')),
    );
  }
}
