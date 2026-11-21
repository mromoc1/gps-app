import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

import 'config.dart';
import 'models.dart';

/// Instancia única usada por toda la app.
final TraccarApi api = TraccarApi();

const String _kTokenKey = 'traccar_token';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Cliente de la API de Traccar + estado en vivo (vehículos y posiciones).
class TraccarApi extends ChangeNotifier {
  final http.Client _http = http.Client();
  String? _cookie;
  String? _token;
  String userName = '';
  String userEmail = '';

  final Map<int, Device> devices = {};
  final Map<int, Position> positions = {};

  final StreamController<TEvent> _events = StreamController<TEvent>.broadcast();
  Stream<TEvent> get eventStream => _events.stream;

  IOWebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _reconnectTimer;
  bool _live = false;
  bool socketConnected = false;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_cookie != null) 'Cookie': 'JSESSIONID=$_cookie',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$kServerUrl$path');
    return query == null ? base : base.replace(queryParameters: query);
  }

  Future<http.Response> _guard(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException('El servidor no responde. Revisa tu conexión.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    }
  }

  void _captureCookie(http.Response r) {
    final raw = r.headers['set-cookie'];
    if (raw == null) return;
    final m = RegExp(r'JSESSIONID=([^;,\s]+)').firstMatch(raw);
    if (m != null) _cookie = m.group(1);
  }

  void _readUser(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      userName = (j['name'] ?? '').toString();
      userEmail = (j['email'] ?? '').toString();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- sesión

  /// Inicia sesión y guarda un token de larga duración (no la clave).
  Future<void> login(String email, String password) async {
    final r = await _guard(() => _http.post(
          _uri('/api/session'),
          headers: {'Accept': 'application/json'},
          body: {'email': email.trim(), 'password': password},
        ));
    if (r.statusCode == 401) {
      throw ApiException('Correo o clave incorrectos.');
    }
    if (r.statusCode != 200) {
      throw ApiException('Error del servidor (${r.statusCode}).');
    }
    _captureCookie(r);
    _readUser(utf8.decode(r.bodyBytes));
    try {
      final exp = DateTime.now()
          .toUtc()
          .add(const Duration(days: 365))
          .toIso8601String();
      final t = await _guard(() => _http.post(
            _uri('/api/session/token'),
            headers: _headers,
            body: {'expiration': exp},
          ));
      if (t.statusCode == 200 && t.body.trim().isNotEmpty) {
        _token = t.body.trim();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTokenKey, _token!);
      }
    } catch (_) {
      // Sin token la sesión funciona igual; solo no se recordará.
    }
  }

  /// Retoma la sesión guardada. Devuelve false si no hay sesión válida.
  /// Lanza [ApiException] si no hay conexión.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_kTokenKey);
    if (t == null) return false;
    _token = t;
    final r = await _guard(() => _http.get(
          _uri('/api/session', {'token': t}),
          headers: {'Accept': 'application/json'},
        ));
    if (r.statusCode != 200) {
      await prefs.remove(_kTokenKey);
      _token = null;
      return false;
    }
    _captureCookie(r);
    _readUser(utf8.decode(r.bodyBytes));
    return true;
  }

  Future<bool> _reauth() async {
    final t = _token;
    if (t == null) return false;
    try {
      final r = await _guard(() => _http.get(
            _uri('/api/session', {'token': t}),
            headers: {'Accept': 'application/json'},
          ));
      if (r.statusCode != 200) return false;
      _captureCookie(r);
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> logout() async {
    stopLive();
    try {
      await _http
          .delete(_uri('/api/session'), headers: _headers)
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    _cookie = null;
    _token = null;
    userName = '';
    userEmail = '';
    devices.clear();
    positions.clear();
    notifyListeners();
  }

  // ----------------------------------------------------------------- datos

  Future<dynamic> _getJson(String path, [Map<String, String>? q]) async {
    var r = await _guard(() => _http.get(_uri(path, q), headers: _headers));
    if (r.statusCode == 401 && await _reauth()) {
      r = await _guard(() => _http.get(_uri(path, q), headers: _headers));
    }
    if (r.statusCode == 401) {
      throw ApiException('Tu sesión expiró. Ingresa de nuevo.');
    }
    if (r.statusCode != 200) {
      throw ApiException('Error del servidor (${r.statusCode}).');
    }
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<void> loadAll() async {
    final ds = await _getJson('/api/devices') as List<dynamic>;
    final ps = await _getJson('/api/positions') as List<dynamic>;
    devices.clear();
    for (final e in ds) {
      final d = Device.fromJson(e as Map<String, dynamic>);
      devices[d.id] = d;
    }
    positions.clear();
    for (final e in ps) {
      final p = Position.fromJson(e as Map<String, dynamic>);
      positions[p.deviceId] = p;
    }
    notifyListeners();
  }

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<List<Position>> route(int deviceId, DateTime from, DateTime to) async {
    final list = await _getJson('/api/reports/route', {
      'deviceId': '$deviceId',
      'from': _iso(from),
      'to': _iso(to),
    }) as List<dynamic>;
    return list
        .map((e) => Position.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TEvent>> events(int deviceId, DateTime from, DateTime to) async {
    final list = await _getJson('/api/reports/events', {
      'deviceId': '$deviceId',
      'from': _iso(from),
      'to': _iso(to),
    }) as List<dynamic>;
    final out = list
        .map((e) => TEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    out.sort((a, b) => (b.eventTime ?? DateTime(0))
        .compareTo(a.eventTime ?? DateTime(0)));
    return out;
  }

  /// Envía un comando. Devuelve true si se envió al equipo y false si quedó
  /// en cola porque el equipo está desconectado.
  Future<bool> sendCommand(int deviceId, String type) async {
    Future<http.Response> send() => _http.post(
          _uri('/api/commands/send'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'type': type,
            'attributes': <String, dynamic>{},
          }),
        );
    var r = await _guard(send);
    if (r.statusCode == 401 && await _reauth()) r = await _guard(send);
    if (r.statusCode == 200) return true;
    if (r.statusCode == 202) return false;
    if (r.statusCode == 401) {
      throw ApiException('Tu sesión expiró. Ingresa de nuevo.');
    }
    throw ApiException('No se pudo enviar el comando (${r.statusCode}).');
  }

  // --------------------------------------------------------------- en vivo

  void startLive() {
    if (_live) return;
    _live = true;
    _connectSocket();
  }

  void stopLive() {
    _live = false;
    _reconnectTimer?.cancel();
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.sink.close();
    _socket = null;
    socketConnected = false;
  }

  Future<void> _connectSocket() async {
    _reconnectTimer?.cancel();
    if (!_live) return;
    final ws = kServerUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    try {
      final ch = IOWebSocketChannel.connect(
        Uri.parse('$ws/api/socket'),
        headers: _headers,
        pingInterval: const Duration(seconds: 25),
      );
      _socket = ch;
      await ch.ready;
      if (!_live) {
        ch.sink.close();
        return;
      }
      socketConnected = true;
      notifyListeners();
      _socketSub = ch.stream.listen(
        _onSocketData,
        onDone: _onSocketClosed,
        onError: (Object _) => _onSocketClosed(),
        cancelOnError: true,
      );
    } catch (_) {
      await _reauth();
      _onSocketClosed();
    }
  }

  void _onSocketClosed() {
    socketConnected = false;
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    notifyListeners();
    if (!_live) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      try {
        await loadAll();
      } catch (_) {}
      _connectSocket();
    });
  }

  void _onSocketData(dynamic data) {
    try {
      final j = jsonDecode(data as String) as Map<String, dynamic>;
      var changed = false;
      for (final e in (j['devices'] as List<dynamic>? ?? const [])) {
        final d = Device.fromJson(e as Map<String, dynamic>);
        devices[d.id] = d;
        changed = true;
      }
      for (final e in (j['positions'] as List<dynamic>? ?? const [])) {
        final p = Position.fromJson(e as Map<String, dynamic>);
        positions[p.deviceId] = p;
        changed = true;
      }
      for (final e in (j['events'] as List<dynamic>? ?? const [])) {
        _events.add(TEvent.fromJson(e as Map<String, dynamic>));
      }
      if (changed) notifyListeners();
    } catch (_) {}
  }
}
