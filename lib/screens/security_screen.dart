import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api.dart';
import '../totp.dart';
import '../util.dart';

/// Verificación en dos pasos con una app de autenticación
/// (Google Authenticator, Microsoft Authenticator, etc.).
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  String? _secret; // clave nueva mientras se configura
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await api.generateTotpKey();
      setState(() => _secret = s);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final s = _secret;
    if (s == null) return;
    if (!Totp.verify(s, _code.text)) {
      setState(() => _error = 'El código no coincide. Revisa que la hora del celular sea automática e inténtalo de nuevo.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.updateUser({'totpKey': s});
      if (!mounted) return;
      setState(() => _secret = null);
      _code.clear();
      showMessage(context, 'Verificación en dos pasos activada.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Desactivar verificación'),
        content: const Text('Tu cuenta quedará protegida solo con la clave. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Desactivar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await api.updateUser({'totpKey': null});
      if (mounted) showMessage(context, 'Verificación en dos pasos desactivada.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación en dos pasos')),
      body: ListenableBuilder(
        listenable: api,
        builder: (context, _) {
          final enabled = api.totpEnabled;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: Icon(enabled ? Icons.verified_user : Icons.shield_outlined,
                      color: enabled ? Colors.green.shade700 : t.colorScheme.onSurfaceVariant),
                  title: Text(enabled ? 'Activada' : 'Desactivada'),
                  subtitle: Text(enabled
                      ? 'Al iniciar sesión se pide la clave y un código de 6 dígitos.'
                      : 'Agrega un código de tu celular además de la clave.'),
                ),
              ),
              const SizedBox(height: 16),
              if (enabled && _secret == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.remove_moderator_outlined),
                  label: const Text('Desactivar'),
                  onPressed: _busy || api.userReadonly ? null : _disable,
                ),
              if (!enabled && _secret == null)
                FilledButton.icon(
                  icon: const Icon(Icons.add_moderator_outlined),
                  label: const Text('Activar'),
                  onPressed: _busy || api.userReadonly ? null : _start,
                ),
              if (_secret != null) ...[
                Text('1. Abre Google Authenticator (o similar), toca "+" y escanea este código:',
                    style: t.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: Totp.uri(_secret!, api.userEmail),
                      size: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('¿No puedes escanear? Ingresa esta clave a mano:',
                    style: t.textTheme.bodySmall),
                Row(children: [
                  Expanded(
                    child: SelectableText(_secret!,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ),
                  IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _secret!));
                      showMessage(context, 'Clave copiada');
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                Text('2. Escribe el código de 6 dígitos que muestra la app:',
                    style: t.textTheme.bodyMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código',
                    prefixIcon: Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _secret = null),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _confirm,
                    child: const Text('Confirmar y activar'),
                  ),
                ]),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: t.colorScheme.error)),
              ],
            ],
          );
        },
      ),
    );
  }
}
