import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

import 'app_theme.dart';
import 'pages/welcome_page.dart';
import 'pages/main_screen.dart';
import 'amplifyconfiguration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // Configure Amplify and Auth plugin before runApp
  final authPlugin = AmplifyAuthCognito();
  try {
    await Amplify.addPlugin(authPlugin);
    await Amplify.configure(amplifyconfig);
    safePrint('✅ Amplify configured');
  } on AmplifyAlreadyConfiguredException {
    safePrint('⚠️ Amplify already configured (skipping)');
  } catch (e, st) {
    safePrint('❌ Amplify configure failed: $e\n$st');
    // We continue so the app can still run, but auth functionality will not work.
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const ExpenseTrackerAppBootstrap(),
    ),
  );
}

/// Bootstrapper that checks whether the user is already signed in,
/// then shows MainScreen or WelcomePage accordingly.
class ExpenseTrackerAppBootstrap extends StatefulWidget {
  const ExpenseTrackerAppBootstrap({super.key});

  @override
  State<ExpenseTrackerAppBootstrap> createState() =>
      _ExpenseTrackerAppBootstrapState();
}

class _ExpenseTrackerAppBootstrapState
    extends State<ExpenseTrackerAppBootstrap> {
  bool _checking = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthSession();
  }

  Future<void> _checkAuthSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      setState(() {
        _signedIn = session.isSignedIn;
      });
    } catch (e) {
      safePrint('Error checking auth session: $e');
      setState(() {
        _signedIn = false;
      });
    } finally {
      setState(() {
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reuse your original theme definitions so UI stays identical.
    final cardTheme = CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 4),
    );

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorSchemeSeed: Colors.blue,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      cardTheme: cardTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.black87),
        titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blue,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.black,
      cardTheme: cardTheme.copyWith(color: const Color(0xFF1E1E1E)),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
      ),
    );

    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        if (_checking) {
          // show a minimal splash while we check auth session
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeNotifier.themeMode,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          title: 'Expense Tracker',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.themeMode,
          debugShowCheckedModeBanner: false,
          // Route to MainScreen if already signed in; otherwise start at WelcomePage
          home: _signedIn ? const MainScreen() : const WelcomePage(),
        );
      },
    );
  }
}
