import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'models.dart';

final DateFormat _dateTime = DateFormat("d MMM yyyy, HH:mm", 'es');
final DateFormat _time = DateFormat('HH:mm', 'es');
final DateFormat _day = DateFormat("EEEE d 'de' MMMM", 'es');

String fmtDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
String fmtTime(DateTime? d) => d == null ? '—' : _time.format(d);
String fmtDay(DateTime d) {
  final s = _day.format(d);
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String timeAgo(DateTime? d) {
  if (d == null) return 'sin datos';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays == 1) return 'ayer';
  return 'hace ${diff.inDays} días';
}

String statusLabel(String status) {
  switch (status) {
    case 'online':
      return 'En línea';
    case 'offline':
      return 'Desconectado';
    default:
      return 'Sin señal reciente';
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'online':
      return Colors.green.shade600;
    case 'offline':
      return Colors.red.shade400;
    default:
      return Colors.orange.shade600;
  }
}

String fmtNum(double? v, {int decimals = 1, String unit = ''}) {
  if (v == null) return '—';
  final s = v.toStringAsFixed(decimals).replaceAll('.', ',');
  return unit.isEmpty ? s : '$s $unit';
}

const Map<String, String> _alarmNames = {
  'sos': 'Botón de pánico',
  'powerCut': 'Corte de energía',
  'powerRestored': 'Energía restablecida',
  'lowBattery': 'Batería baja',
  'lowPower': 'Voltaje bajo',
  'tow': 'Remolque o grúa',
  'accident': 'Posible accidente',
  'jamming': 'Bloqueo de señal',
  'vibration': 'Vibración',
  'movement': 'Movimiento',
  'overspeed': 'Exceso de velocidad',
  'tampering': 'Manipulación del equipo',
  'removing': 'Equipo removido',
  'door': 'Puerta abierta',
  'gpsAntennaCut': 'Antena GPS cortada',
};

const Map<String, String> _eventNames = {
  'deviceOnline': 'Equipo en línea',
  'deviceOffline': 'Equipo desconectado',
  'deviceUnknown': 'Equipo sin señal reciente',
  'deviceInactive': 'Equipo inactivo',
  'deviceMoving': 'Vehículo en movimiento',
  'deviceStopped': 'Vehículo detenido',
  'deviceOverspeed': 'Exceso de velocidad',
  'ignitionOn': 'Motor encendido',
  'ignitionOff': 'Motor apagado',
  'geofenceEnter': 'Entró a una zona',
  'geofenceExit': 'Salió de una zona',
  'commandResult': 'Respuesta del equipo',
  'queuedCommandSent': 'Comando en cola enviado',
  'maintenance': 'Mantención',
  'driverChanged': 'Cambio de conductor',
  'deviceFuelDrop': 'Baja de combustible',
  'textMessage': 'Mensaje del equipo',
};

String eventLabel(TEvent e) {
  if (e.type == 'alarm') {
    final a = e.alarm;
    return 'Alarma: ${_alarmNames[a] ?? a ?? 'general'}';
  }
  return _eventNames[e.type] ?? e.type;
}

IconData eventIcon(String type) {
  switch (type) {
    case 'alarm':
      return Icons.warning_amber_rounded;
    case 'deviceOverspeed':
      return Icons.speed;
    case 'ignitionOn':
      return Icons.key;
    case 'ignitionOff':
      return Icons.key_off;
    case 'geofenceEnter':
    case 'geofenceExit':
      return Icons.fence;
    case 'deviceOnline':
      return Icons.cloud_done_outlined;
    case 'deviceOffline':
    case 'deviceUnknown':
      return Icons.cloud_off_outlined;
    case 'deviceMoving':
      return Icons.directions_car;
    case 'deviceStopped':
      return Icons.local_parking;
    case 'commandResult':
    case 'queuedCommandSent':
      return Icons.settings_remote;
    default:
      return Icons.notifications_none;
  }
}

Color eventColor(String type) {
  switch (type) {
    case 'alarm':
    case 'deviceOverspeed':
      return Colors.red.shade600;
    case 'deviceOffline':
    case 'deviceUnknown':
      return Colors.orange.shade700;
    case 'ignitionOn':
    case 'deviceOnline':
      return Colors.green.shade700;
    default:
      return Colors.blueGrey.shade600;
  }
}

/// Distancia recorrida en km sumando los tramos entre posiciones.
double routeKm(List<Position> pts) {
  const d = Distance();
  var meters = 0.0;
  for (var i = 1; i < pts.length; i++) {
    meters += d.distance(pts[i - 1].latLng, pts[i].latLng).toDouble();
  }
  return meters / 1000;
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
