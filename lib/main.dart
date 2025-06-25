import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
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
      home: const ExitConfirmationWrapper(child: InitializationScreen()),
      routes: {
        '/welcome': (context) => const ExitConfirmationWrapper(child: WelcomeScreen()),
        '/login': (context) => const ExitConfirmationWrapper(child: LoginScreen()),
        '/register': (context) => const ExitConfirmationWrapper(child: RegisterScreen()),
        '/forgot-password': (context) => const ExitConfirmationWrapper(child: ForgotPasswordScreen()),
        '/password-changed': (context) => const ExitConfirmationWrapper(child: PasswordChangedScreen()),
        '/map': (context) => const ExitConfirmationWrapper(child: MapScreen()),
        '/home': (context) => const ExitConfirmationWrapper(child: HomeScreen()),
        '/camera': (context) => const ExitConfirmationWrapper(child: CameraSelectionScreen()),
        '/upload-image': (context) => const ExitConfirmationWrapper(child: UploadImageScreen()),
        '/profile': (context) => const ExitConfirmationWrapper(child: ProfileScreen()),
        '/nearest-petrol-pumps': (context) => const ExitConfirmationWrapper(child: NearestPetrolPumpsScreen()),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/otp-verification') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ExitConfirmationWrapper(
              child: OtpVerificationScreen(
                mobile: args['mobile'],
              ),
            ),
          );
        } else if (settings.name == '/create-new-password') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ExitConfirmationWrapper(
              child: CreateNewPasswordScreen(
                mobile: args['mobile'],
                otp: args['otp'],
              ),
            ),
          );
        }
        return null;
      },
    );
  }
}

class ExitConfirmationWrapper extends StatelessWidget {
  final Widget child;

  const ExitConfirmationWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show exit confirmation dialog
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  color: Colors.teal.withOpacity(0.8),
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Exit App',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to exit the app?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Exit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          // Exit the app
          if (Platform.isAndroid) {
            exit(0);
          } else {
            // For iOS, we can't force exit, but we can pop to root
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }

        return false; // Prevent default back button behavior
      },
      child: child,
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
              'assets/images/branding.png',
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