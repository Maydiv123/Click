import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/create_new_password_screen.dart';
import 'screens/password_changed_screen.dart';
import 'screens/map_screen.dart';
import 'screens/home_screen.dart';
import 'screens/camera_selection_screen.dart';
import 'screens/upload_image_screen.dart';
import 'screens/nearest_petrol_pumps_screen.dart';
import 'firebase_options.dart';
import 'screens/profile_screen.dart';
import 'services/firestore_init_service.dart';
import 'services/custom_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Click App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const InitializationScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/password-changed': (context) => const PasswordChangedScreen(),
        '/map': (context) => const MapScreen(),
        '/home': (context) => const HomeScreen(),
        '/camera': (context) => const CameraSelectionScreen(),
        '/upload-image': (context) => const UploadImageScreen(),
        '/profile': (context) => ProfileScreen(),
        '/nearest-petrol-pumps': (context) => const NearestPetrolPumpsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/otp-verification') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              mobile: args['mobile'],
            ),
          );
        } else if (settings.name == '/create-new-password') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => CreateNewPasswordScreen(
              mobile: args['mobile'],
              otp: args['otp'],
            ),
          );
        }
        return null;
      },
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({Key? key}) : super(key: key);

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  final CustomAuthService _authService = CustomAuthService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Firestore collections
      final firestoreInitService = FirestoreInitService();
      await firestoreInitService.initializeCollections();
      
      if (mounted) {
        // Check if user is already logged in using CustomAuthService
        final isLoggedIn = await _authService.isUserLoggedIn();
        if (isLoggedIn) {
          // User is logged in, navigate to home screen
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // No user logged in, navigate to welcome screen
          Navigator.pushReplacementNamed(context, '/welcome');
        }
      }
    } catch (e) {
      if (mounted) {
        // Show error dialog if initialization fails
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Initialization Error'),
            content: Text('Failed to initialize app: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _initializeApp(); // Retry initialization
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.local_gas_station,
                size: 100,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Initializing...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 