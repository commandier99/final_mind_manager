import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'shared/presentation/pages/splash_screen.dart';
import 'shared/presentation/pages/main_screen.dart';
import 'features/authentication/presentation/pages/authentication_screen.dart';
import 'features/authentication/datasources/providers/authentication_provider.dart';
import 'shared/features/users/datasources/providers/user_provider.dart';
import 'shared/features/users/datasources/providers/user_stats_provider.dart';
import 'shared/features/users/datasources/providers/user_daily_activity_provider.dart';
import 'features/tasks/datasources/providers/task_provider.dart';
import 'features/plans/datasources/providers/plan_provider.dart';
import 'shared/datasources/providers/navigation_provider.dart';
import 'features/boards/datasources/providers/board_provider.dart';
import 'features/boards/datasources/providers/board_stats_provider.dart';
import 'shared/features/search/providers/search_provider.dart';
import 'features/boards/datasources/providers/board_request_provider.dart';
import 'shared/features/users/datasources/providers/activity_event_provider.dart';
import 'features/tasks/datasources/providers/upload_progress_provider.dart';
import 'features/notifications/datasources/providers/in_app_notif_provider.dart';
import 'features/notifications/datasources/providers/push_notif_provider.dart';
import 'shared/services/firebase_messaging_service.dart';
import 'shared/utilities/cloudinary_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize permission handler
  await Permission.notification.isDenied.then((isDenied) {
    if (isDenied) {
      print('[main.dart] Notification permission is denied');
    }
  });
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase Messaging
  await FirebaseMessagingService().initialize();
  
  // Initialize Cloudinary for file uploads
  CloudinaryService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => UserStatsProvider()),
        ChangeNotifierProvider(create: (_) => UserDailyActivityProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => PlanProvider()),
        ChangeNotifierProvider(create: (_) => BoardProvider()),
        ChangeNotifierProvider(create: (_) => BoardStatsProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => BoardRequestProvider()),
        ChangeNotifierProvider(create: (_) => InAppNotificationProvider()),
        ChangeNotifierProvider(create: (_) => PushNotificationProvider()),
        ChangeNotifierProvider(create: (_) => ActivityEventProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => UploadProgressProvider()),
        ChangeNotifierProxyProvider<UserProvider, AuthenticationProvider>(
          create: (context) => AuthenticationProvider(),
          update: (context, userProvider, authProvider) {
            // Connect AuthenticationProvider to UserProvider via callback
            if (authProvider != null) {
              authProvider.onUserAuthenticated = (userId) {
                print('[DEBUG] main.dart: onUserAuthenticated callback triggered for userId: $userId');
                userProvider.loadUserData(userId);
                // Register FCM token for user
                FirebaseMessagingService().registerTokenForUser(userId);
                // Reset NavigationProvider to home page on sign in
                context.read<NavigationProvider>().selectFromBottomNav(0);
              };
            }
            return authProvider ?? AuthenticationProvider();
          },
        ),
      ],
      child: MaterialApp(
        title: 'Mind Manager',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/auth': (context) => const AuthenticationScreen(),
          '/home': (context) => const MainScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

