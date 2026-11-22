import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api.dart';
import 'brand.dart';
import 'config.dart';
import 'marker_icons.dart';
import 'push.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await MarkerIcons.preload();
  await Push.init();
  runApp(const GpsApp());
}

class GpsApp extends StatelessWidget {
  const GpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: kBrandNavy,
      primary: kBrandNavy,
      secondary: kBrandOrange,
    );
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        appBarTheme: const AppBarTheme(centerTitle: false),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(kRadiusButton),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: roundedShape(kRadiusButton)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(shape: roundedShape(kRadiusButton)),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(shape: roundedShape(kRadiusButton)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(shape: roundedShape(kRadiusButton)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: roundedShape(kRadiusCard),
        ),
        cardTheme: CardThemeData(shape: roundedShape(kRadiusCard)),
        navigationBarTheme: NavigationBarThemeData(
          indicatorShape: roundedShape(kRadiusButton),
        ),
        popupMenuTheme: PopupMenuThemeData(shape: roundedShape(kRadiusButton)),
        dialogTheme: DialogThemeData(shape: roundedShape(kRadiusSheet)),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: roundedShape(kRadiusButton),
        ),
      ),
      home: const StartScreen(),
    );
  }
}

/// Pantalla inicial: retoma la sesión guardada o muestra el login.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      final ok = await api.restoreSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ok ? const HomeScreen() : const LoginScreen(),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _error == null
          ? const Center(child: BrandLogo(size: 88))
          : CenteredMessage(
              icon: Icons.wifi_off,
              text: _error!,
              actionLabel: 'Reintentar',
              onAction: _start,
            ),
    );
  }
}
