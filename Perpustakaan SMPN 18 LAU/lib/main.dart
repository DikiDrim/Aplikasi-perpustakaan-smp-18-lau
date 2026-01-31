import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/fcm_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'screens/home_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/login_siswa_screen.dart';
import 'screens/register_screen.dart';
import 'services/notification_service.dart';
import 'utils/admin_setup.dart';
import 'providers/global_loading_provider.dart';
import 'widgets/loading_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi WebView Platform untuk Android
  if (!kIsWeb) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
  }
  String? initError;

  // Initialize Firebase safely (avoid duplicate-app error)
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // Register background handler for FCM
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}

    // Buat akun admin khusus jika belum ada (hanya sekali)
    try {
      await AdminSetup.createAdminAccount();
    } catch (e) {
      // Tidak fatal jika admin sudah ada
      debugPrint('Admin setup: $e');
    }
  } catch (e, st) {
    initError = 'Firebase initialize error: $e';
    // keep printing stack for debugging
    debugPrint(initError);
    debugPrint(st.toString());
  }

  // Load environment variables (for Cloudinary keys, etc.) — don't crash app when .env missing
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    // Not fatal — log and continue. Missing .env can be acceptable in some setups.
    debugPrint('Warning: .env load failed: $e');
    debugPrint(st.toString());
  }

  // Initialize local notifications only on non-web platforms; guard against plugin errors
  if (!kIsWeb) {
    try {
      await NotificationService.init();
    } catch (e, st) {
      debugPrint('Warning: NotificationService.init failed: $e');
      debugPrint(st.toString());
    }
    // Initialize FCM client and request notification permission where needed
    try {
      await FcmService.init();
      try {
        await FirebaseMessaging.instance.requestPermission();
      } catch (e) {
        // ignore permission errors on platforms where not applicable
      }
    } catch (e, st) {
      debugPrint('Warning: FcmService.init failed: $e');
      debugPrint(st.toString());
    }
  }

  // Initialize date formatting for Indonesian locale
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('Warning: Date formatting initialization failed: $e');
  }

  runApp(MyApp(initError: initError));
}

class MyApp extends StatelessWidget {
  final String? initError;

  const MyApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GlobalLoading()),
      ],
      child: MaterialApp(
        title: 'Perpustakaan SMPN 18 LAU',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
          useMaterial3: true,
          primaryColor: const Color(0xFF0D47A1),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (_) => const RoleSelectionScreen(),
          '/login': (_) => const LoginScreen(),
          '/login-siswa': (_) => const LoginSiswaScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const HomeScreen(),
        },
        builder: (context, child) {
          // Inject global loading overlay above all routes
          return Stack(
            children: [if (child != null) child, const LoadingOverlay()],
          );
        },
      ),
    );
  }
}

// If initialization failed before runApp, show a helpful error screen.
class InitErrorScreen extends StatelessWidget {
  final String message;
  const InitErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App initialization error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Text(message, style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }
}
