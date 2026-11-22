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

/// El servidor pide el código de verificación en dos pasos.
class CodeRequiredException extends ApiException {
  CodeRequiredException() : super('Ingresa el código de tu app de autenticación.');
}

/// Cliente de la API de Traccar + estado en vivo (vehículos y posiciones).
class TraccarApi extends ChangeNotifier {
  final http.Client _http = http.Client();
  String? _cookie;
  String? _token;
  String userName = '';
  String userEmail = '';

  /// Usuario completo tal como lo entrega Traccar (para actualizarlo).
  Map<String, dynamic> user = {};
  int? get userId => (user['id'] as num?)?.toInt();
  DateTime? get userExpiration =>
      user['expirationTime'] == null ? null : DateTime.tryParse('${user['expirationTime']}')?.toLocal();
  bool get userReadonly => user['readonly'] == true;
  bool get totpEnabled => (user['totpKey'] ?? '').toString().isNotEmpty;

  final Map<int, DeviceGroup> groups = {};

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
      user = j;
      userName = (j['name'] ?? '').toString();
      userEmail = (j['email'] ?? '').toString();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- sesión

  /// Inicia sesión y guarda un token de larga duración (no la clave).
  Future<void> login(String email, String password, {String? code}) async {
    final r = await _guard(() => _http.post(
          _uri('/api/session'),
          headers: {'Accept': 'application/json'},
          body: {
            'email': email.trim(),
            'password': password,
            if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
          },
        ));
    if (r.statusCode == 401) {
      final auth = (r.headers['www-authenticate'] ?? '').toUpperCase();
      if (auth.contains('TOTP')) {
        if (code != null && code.trim().isNotEmpty) {
          throw ApiException('Código incorrecto o vencido. Intenta con el siguiente.');
        }
        throw CodeRequiredException();
      }
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

  /// Pide al servidor un correo para restablecer la clave.
  Future<void> requestPasswordReset(String email) async {
    final r = await _guard(() => _http.post(
          _uri('/api/password/reset'),
          headers: {'Accept': 'application/json'},
          body: {'email': email.trim()},
        ));
    if (r.statusCode >= 500) {
      throw ApiException('El servidor no pudo enviar el correo. Intenta más tarde.');
    }
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
    user = {};
    groups.clear();
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

  /// POST/PUT/DELETE con JSON y reintento de sesión.
  Future<http.Response> _send(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    Future<http.Response> go() async {
      final req = http.Request(method, _uri(path, query));
      req.headers.addAll({..._headers, 'Content-Type': 'application/json'});
      if (body != null) req.body = jsonEncode(body);
      return http.Response.fromStream(await _http.send(req));
    }

    var r = await _guard(go);
    if (r.statusCode == 401 && await _reauth()) r = await _guard(go);
    if (r.statusCode == 401) {
      throw ApiException('Tu sesión expiró. Ingresa de nuevo.');
    }
    if (r.statusCode >= 400) {
      final msg = utf8.decode(r.bodyBytes);
      throw ApiException('No se pudo guardar (${r.statusCode})'
          '${msg.isNotEmpty && msg.length < 160 ? ': $msg' : '.'}');
    }
    return r;
  }

  // ----------------------------------------------------------- usuario

  Future<void> refreshUser() async {
    final j = await _getJson('/api/session');
    _readUser(jsonEncode(j));
    notifyListeners();
  }

  /// Guarda cambios en el usuario actual (atributos, clave de dos pasos).
  Future<void> updateUser(Map<String, dynamic> changes) async {
    final id = userId;
    if (id == null) throw ApiException('No hay sesión.');
    final body = {...user, ...changes};
    final r = await _send('PUT', '/api/users/$id', body: body);
    _readUser(utf8.decode(r.bodyBytes));
    notifyListeners();
  }

  Map<String, dynamic> get userAttributes =>
      Map<String, dynamic>.from((user['attributes'] as Map?) ?? const {});

  /// Genera una clave nueva para la app de autenticación (no la activa).
  Future<String> generateTotpKey() async {
    final r = await _send('POST', '/api/users/totp');
    return utf8.decode(r.bodyBytes).trim().replaceAll('"', '');
  }

  // ----------------------------------------------------------- zonas

  Future<List<Geofence>> geofences({int? deviceId}) async {
    final list = await _getJson('/api/geofences',
        deviceId == null ? null : {'deviceId': '$deviceId'}) as List<dynamic>;
    return list.map((e) => Geofence.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Geofence> saveGeofence({int? id, required String name, required String area}) async {
    final body = {if (id != null) 'id': id, 'name': name, 'area': area, 'attributes': <String, dynamic>{}};
    final r = id == null
        ? await _send('POST', '/api/geofences', body: body)
        : await _send('PUT', '/api/geofences/$id', body: body);
    return Geofence.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> deleteGeofence(int id) => _send('DELETE', '/api/geofences/$id');

  Future<void> linkDevice(String key, int objectId, int deviceId, bool linked) =>
      _send(linked ? 'POST' : 'DELETE', '/api/permissions',
          body: {'deviceId': deviceId, key: objectId});

  // ----------------------------------------------------- notificaciones

  Future<List<Map<String, dynamic>>> notifications() async {
    final list = await _getJson('/api/notifications') as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createNotification(String type, {Map<String, dynamic>? attributes}) =>
      _send('POST', '/api/notifications', body: {
        'type': type,
        'always': true,
        'notificators': 'web,firebase',
        'attributes': attributes ?? <String, dynamic>{},
      });

  Future<void> deleteNotification(int id) => _send('DELETE', '/api/notifications/$id');

  Future<void> sendTestNotification() => _send('POST', '/api/notifications/test/firebase');

  /// Registra (o quita) el token del celular para recibir push.
  Future<void> setPushToken(String token, {required bool register}) async {
    final attrs = userAttributes;
    final tokens = ((attrs['notificationTokens'] ?? '') as Object)
        .toString()
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet();
    final changed = register ? tokens.add(token) : tokens.remove(token);
    if (!changed) return;
    attrs['notificationTokens'] = tokens.join(',');
    if (tokens.isEmpty) attrs.remove('notificationTokens');
    await updateUser({'attributes': attrs});
  }

  bool hasPushToken(String token) => ((userAttributes['notificationTokens'] ?? '') as Object)
      .toString()
      .split(',')
      .contains(token);

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
    try {
      final gs = await _getJson('/api/groups') as List<dynamic>;
      groups
        ..clear()
        ..addEntries(gs.map((e) {
          final g = DeviceGroup.fromJson(e as Map<String, dynamic>);
          return MapEntry(g.id, g);
        }));
    } catch (_) {}
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
