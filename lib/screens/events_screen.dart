import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

class EventsScreen extends StatefulWidget {
  final Device device;
  const EventsScreen({super.key, required this.device});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const int _days = 7;
  bool _loading = true;
  String? _error;
  List<TEvent> _events = const [];

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
      final now = DateTime.now();
      _events = await api.events(
        widget.device.id,
        now.subtract(const Duration(days: _days)),
        now.add(const Duration(minutes: 1)),
      );
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = CenteredMessage(
        icon: Icons.error_outline,
        text: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    } else if (_events.isEmpty) {
      body = const CenteredMessage(
        icon: Icons.notifications_none,
        text: 'Sin eventos en los últimos $_days días.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: _events.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = _events[i];
            final c = eventColor(e.type);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: c.withValues(alpha: 0.12),
                child: Icon(eventIcon(e.type), color: c),
              ),
              title: Text(eventLabel(e)),
              subtitle: Text(fmtDateTime(e.eventTime)),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Eventos · ${widget.device.name}')),
      body: body,
    );
  }
}
