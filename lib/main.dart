import 'package:flutter/material.dart'; // import built in material design package for flutter
import 'package:firebase_core/firebase_core.dart'; // import firebase core package to initialize firebase
import 'package:flutter_riverpod/flutter_riverpod.dart'; // import flutter riverpod package for state management
// import configuration for firebase project
import 'package:tpmentorship/firebase_options.dart';
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/session.dart';
import 'package:tpmentorship/models/user_profile.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/biometric_provider.dart';
import 'package:tpmentorship/providers/chat_notification_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/providers/theme_provider.dart';
import 'package:tpmentorship/services/auth_service.dart';
import 'package:tpmentorship/services/notification_service.dart';
import 'package:tpmentorship/theme/app_theme.dart';
import 'package:tpmentorship/utils/snackbar_helper.dart';
// import display screens below
import 'package:tpmentorship/screens/home_screen.dart';
import 'package:tpmentorship/screens/chat_screen.dart';
import 'package:tpmentorship/screens/search_screen.dart';
import 'package:tpmentorship/screens/messages_screen.dart';
import 'package:tpmentorship/screens/profile_screen.dart';
import 'package:tpmentorship/screens/mentor_profile_screen.dart';
import 'package:tpmentorship/screens/lock_screen.dart';
import 'package:tpmentorship/screens/login_screen.dart';
import 'package:tpmentorship/screens/register_screen.dart';
import 'package:tpmentorship/screens/forgot_password_screen.dart';
import 'package:tpmentorship/screens/settings_screen.dart';
// part 3 screens
import 'package:tpmentorship/screens/mentor_detail_screen.dart';
import 'package:tpmentorship/screens/session_detail_screen.dart';
import 'package:tpmentorship/screens/my_sessions_screen.dart';
import 'package:tpmentorship/screens/ai_matches_screen.dart';
import 'package:tpmentorship/screens/edit_profile_screen.dart';
import 'package:tpmentorship/screens/premium_screen.dart';
import 'package:tpmentorship/widgets/offline_banner.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
// handle to clear all previous navigation history when users wants to sign out
// this prevents the user from going back to protected screens that requires log in

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // initialise flutter so firebase can be initialised
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
    // connect to firebase project
  );
  await NotificationService.instance.init();
  // set up local notifications (does nothing on web)
  runApp(const ProviderScope(child: MyApp()));
  // enable riverpod state management for the app
}

class MyApp extends ConsumerWidget {
  // ConsumerWidget so it can watch the theme provider and rebuild
  // the whole app when the user picks a different palette
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themeProvider);
    // rebuilds the app whenever the theme changes

    return MaterialApp(
      // builds and returns what the app should look like
      key: ValueKey(palette.name),
      // changing the key forces every widget to rebuild so screens
      // pick up the new AppTheme colours immediately
      title: 'TP Mentorship',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      // remove debug in top right
      theme: AppTheme.theme,
      scrollBehavior: const NoStretchScrollBehavior(),
      // remove bouncy overscroll effect
      home: const AuthGate(),
    );
  }
}

// this is the class that controls the scroll behaviour (purely aesthetic)
class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  // watches auth state and decides if user is logged in or not and shows the appropriate screen
  // ConsumerWidget is a widget that can read providers and rebuild when they change

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // listen to auth state changes and clear all previous navigation history so user doesnt get stuck on protected screens
    ref.listen(authStateProvider, (previous, next) {
      if (next.hasValue && next.value == null) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });

    final authState = ref.watch(authStateProvider);
    // watch current auth state and rebuild when it changes

    return authState.when(
      // handle loading, error and data states 
      data: (user) {
        // check if user is logged in or not and show the appropriate screens
        if (user != null) {
          // additional feature: if biometric unlock is turned on, hide the
          // app behind the lock screen until the fingerprint matches.
          // firebase keeps the session alive between launches, so this
          // guards that saved session rather than replacing the login
          final lockStatus = ref.watch(biometricLockProvider);
          switch (lockStatus) {
            case LockStatus.checking:
              // still reading the saved flag - a blank themed screen
              // avoids flashing the home page before locking it
              return Scaffold(
                backgroundColor: AppTheme.darkBg,
                body: Center(
                  child: CircularProgressIndicator(color: AppTheme.tpRed),
                ),
              );
            case LockStatus.locked:
              return LockScreen(
                // the escape hatch: sign out so the user can get back in
                // with their password if the sensor is broken
                onUsePassword: () =>
                    ref.read(authServiceProvider).logout(),
              );
            case LockStatus.unlocked:
              return const MainNavigator();
          }
        }
        return const AuthFlow();
      },

      loading: () => Scaffold(
      // loading wheel
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.tpRed),
        ),
      ),
      error: (err, stack) => Scaffold(
        // show error message if there is an error in auth state
        backgroundColor: AppTheme.darkBg,
        body: Center(
          child: Text(
            'Something went wrong: $err',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  // StatefulWidget is a widget that has mutable state and can rebuild when the state changes
  
  @override
  State<AuthFlow> createState() => _AuthFlowState();
  // creates a separate _AuthFlowState to hold that state
  // only within the class itself
}

class _AuthFlowState extends State<AuthFlow> {
  String _screen = 'login';
  // tracks what screen to show

  @override
  Widget build(BuildContext context) {
    // if _screen switches, display the matching screen
    switch (_screen) {
      case 'register':
        return RegisterScreen(
          onGoToLogin: () => setState(() => _screen = 'login'),
        );
      case 'forgot_password':
        return ForgotPasswordScreen(
          onGoToLogin: () => setState(() => _screen = 'login'),
        );
      case 'login':
      default:
        return LoginScreen(
          onGoToRegister: () => setState(() => _screen = 'register'),
          onGoToForgotPassword: () =>
              setState(() => _screen = 'forgot_password'),
        );
    }
  }
}

class MainNavigator extends ConsumerStatefulWidget {
  const MainNavigator({super.key});
  // ConsumerStateful Widget is a widget that has mutable state and can read providers and rebuild when they change

  @override
  ConsumerState<MainNavigator> createState() => _MainNavigatorState();
  // creates a separate _MainNavigatorState to hold that state
}

class _MainNavigatorState extends ConsumerState<MainNavigator> {
  int _selectedIndex = 0;
  // tracks what screen to show in the main navigator (starts at home screen)
  bool _onboardingPromptShown = false;
  // guards the first-time onboarding prompt below so it only ever
  // fires once per app session, not every time the profile stream emits

  @override
  void initState() {
    // runs once when the widget is first created
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _promptForNameIfNeeded());
        // check is user has display name set, if not prompt user to set it
    _setUpFirestoreData();
    // make sure firestore has mentor data and this user has a profile

    ref.read(chatNotificationWatcherProvider);
    // reading the provider is what starts the listener that notifies on
    // incoming messages. MainNavigator only exists while logged in, which
    // is exactly the right lifetime for it
    NotificationService.instance.onChatTap = _openChatFromNotification;
    _handleNotificationLaunch();

    // watch the profile stream outside of build() using listenManual, so
    // we can push a screen the moment we see a first-time user (one whose
    // profile document exists but has never been filled in and saved)
    ref.listenManual<AsyncValue<UserProfile?>>(userProfileProvider,
        (previous, next) {
      final profile = next.value;
      if (profile == null ||
          profile.onboardingComplete ||
          _onboardingPromptShown) {
        return;
      }
      _onboardingPromptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  EditProfileScreen(profile: profile, isOnboarding: true)),
        );
      });
    });
  }

  // one-time firestore setup after login:
  // 1. seed the mentors and students collections if empty (first ever run)
  // 2. create this user's profile document if they dont have one
  Future<void> _setUpFirestoreData() async {
    try {
      await ref.read(mentorServiceProvider).seedMentorsIfEmpty();
      await ref.read(studentServiceProvider).seedStudentsIfEmpty();
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await ref.read(userServiceProvider).createProfileIfMissing(
              uid: user.uid,
              fullName: user.displayName?.trim() ?? '',
            );
      }
    } catch (_) {
      // firestore not reachable (offline or not set up yet) - the
      // screens show their own error states so nothing to do here
    }
  }

  String get _greetingName {
    // get user display name from auth service, if not set return 'Student' as default
    final name = ref.read(authServiceProvider).displayName;
    return name.isNotEmpty ? name : 'Student';
  }

  Future<void> _promptForNameIfNeeded() async {
    // if user signed in with google/git but has no display name set, prompt user to set it
    final authService = ref.read(authServiceProvider);
    // if widget is not mounted (already destroyed), user signed in with email/password or user has display name set, skip
    if (!mounted ||
        authService.isEmailPasswordAccount ||
        authService.displayName.isNotEmpty) {
      return;
    }

    final controller = TextEditingController();
    // grab text input from user to set display name
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      // user cannot dismiss the dialog by tapping outside of it, field is required
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCardBg,
        title: Text(
          'What should TPMentorship call you?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
            },
            child: Text('Save',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    // save name to firebase 
    controller.dispose();
    if (name.isEmpty) return;
    try {
      await ref.read(authServiceProvider).updateDisplayName(name);
    } catch (e) {
      if (mounted) _showSnackBar(AuthService.friendlyError(e));
    }
    if (mounted) setState(() {});
  }

// change the selected tab and rebuild the widget when user taps on a bottom navigation item
  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  // ---------- part 3 navigation helpers ----------
  // each one pushes the matching screen on top of the current one

  void _openMentorDetail(Mentor mentor) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => MentorDetailScreen(mentor: mentor)),
    );
  }

  void _openSessionDetail(Session session) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SessionDetailScreen(sessionId: session.id)),
    );
  }

  void _openMySessions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MySessionsScreen()),
    );
  }

  void _openAiMatches() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AiMatchesScreen()),
    );
  }

  void _openPremium() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PremiumScreen()),
    );
  }

  void _openEditProfile() {
    // the edit form needs the current profile values to pre-fill with
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) {
      _showSnackBar('Your profile is still loading, try again in a moment');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditProfileScreen(profile: profile)),
    );
  }

  @override
  void dispose() {
    // this screen only exists while logged in, and the handler below
    // closes over its state - leaving it wired up after logout would let
    // a notification still sitting in the tray push someone's chat on top
    // of the login screen
    NotificationService.instance.onChatTap = null;
    super.dispose();
  }

  // opens the chat a tapped notification came from
  void _openChatFromNotification(String otherUid, String otherName) {
    if (!mounted) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) =>
            ChatScreen(otherUid: otherUid, otherName: otherName),
      ),
    );
  }

  // a notification can outlive the app in the tray - if one launched us,
  // route to that chat now that there is a navigator to push onto
  Future<void> _handleNotificationLaunch() async {
    final payload = await NotificationService.instance.launchPayload();
    if (payload == null || !mounted) return;
    _openChatFromNotification(payload.senderUid, payload.senderName);
  }

// show a snackbar with the given message but only if widget is still mounted (not destroyed)
  void _showSnackBar(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

// log the user out and show a snackbar if there is an error
  void _logout() {
    ref.read(authServiceProvider).logout().catchError((Object e) {
      if (mounted) _showSnackBar(AuthService.friendlyError(e));
    });
  }

  // opens the dedicated account settings screen
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( 
      // Scaffold is a widget that provides a basic material design visual layout structure
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        // prevents content from being drawn under system status bar, notches, etc
        child: Column(
          children: [
            const OfflineBanner(),
            // slides in when the device loses connection (additional feature)
            Expanded(
              child: IndexedStack(
                // IndexedStack shows all 5 screens but only the selected index is displayed
                // preserves the state of other screens when switching between them (scroll position etc.)
                index: _selectedIndex,
                children: [
                  HomeScreen(
                    // home screen is the first screen that is displayed when user logs in
                    userName: _greetingName,
                    onMentorTap: _openMentorDetail,
                    // opens the mentor's full profile (part 3)
                    onSessionTap: _openSessionDetail,
                    // opens the session's detail screen (part 3)
                    onViewAllSessions: _openMySessions,
                    // opens the full sessions list (part 3)
                    onViewAllAiMatches: _openAiMatches,
                    // opens the AI recommendations screen (part 3)
                    onViewAllMessages: () => setState(() => _selectedIndex = 2),
                    // navigate to messages screen when user taps view all messages
                    onNavigateToSearch: () => setState(() => _selectedIndex = 1),
                    // navigate to search screen when user clicks on the navbar
                    onNavigateToMessages: () => setState(() => _selectedIndex = 2),
                    // navigate to messages screen when user clicks on the navbar
                  ),
                  SearchScreen(
                    onMentorTap: _openMentorDetail,
                    // opens the mentor's full profile (part 3)
                    onBack: () => setState(() => _selectedIndex = 0),
                    // go back to home screen when user taps back button
                  ),
                  MessagesScreen(
                    onBack: () => setState(() => _selectedIndex = 0),
                    // go back to home screen when user taps back button
                  ),
                  ProfileScreen(
                    userName: _greetingName,
                    // welcome message
                    onEditProfile: _openEditProfile,
                    // opens the profile editing form (part 3)
                    onSettings: _openSettings,
                    // open settings bottom modal screen
                    onLogout: _logout,
                    // open logout
                    onSessionTap: _openSessionDetail,
                    // opens the session's detail screen (part 3)
                    onSeeMore: _openMySessions,
                    // opens the full sessions list (part 3)
                    onGoPremium: _openPremium,
                    // opens the NETS QR premium upgrade screen (part 3)
                    onBack: () => setState(() => _selectedIndex = 0),
                    // go back home
                  ),
                  MentorProfileScreen(
                    onBack: () => setState(() => _selectedIndex = 0),
                    // go back home
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // display all the different tabs user can navigate to
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Mentor Profile'),
        ],
      ),
    );
  }
}
