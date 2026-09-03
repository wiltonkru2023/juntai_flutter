import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/notification_service.dart';
import '../../features/activities/presentation/screens/activity_details_screen.dart';
import '../../features/activities/presentation/screens/create_activity_screen.dart';
import '../../features/activities/presentation/screens/edit_activity_screen.dart';
import '../../features/activities/presentation/screens/participants_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/location_permission_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/chat/presentation/screens/group_chat_screen.dart';
import '../../features/chat/presentation/screens/private_chat_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/discoveries/presentation/screens/discoveries_screen.dart';
import '../../features/discoveries/presentation/screens/discovery_details_screen.dart';
import '../../features/discoveries/presentation/screens/business_center_screen.dart';
import '../../features/discoveries/presentation/screens/create_discovery_screen.dart';
import '../../features/discoveries/presentation/screens/business_profile_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/blocked_users_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/help_screen.dart';
import '../../features/profile/presentation/screens/privacy_policy_screen.dart';
import '../../features/profile/presentation/screens/privacy_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/public_profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/terms_screen.dart';
import '../../features/search/presentation/screens/filters_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/splash/presentation/screens/onboarding_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: notificationNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (_, __) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/location-permission',
        builder: (_, __) => const LocationPermissionScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (_, __) => const HelpScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, __) => const TermsScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),
      ShellRoute(
        builder: (
          context,
          state,
          child,
        ) =>
            MainShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (_, __) => const MapScreen(),
          ),
          GoRoute(
            path: '/activity/create',
            builder: (_, state) => CreateActivityScreen(
                sourceDiscoveryId: state.uri.queryParameters['source']),
          ),
          GoRoute(
              path: '/discover', builder: (_, __) => const DiscoveriesScreen()),
          GoRoute(
              path: '/discovery/:id',
              builder: (_, state) => DiscoveryDetailsScreen(
                  discoveryId: state.pathParameters['id']!)),
          GoRoute(
              path: '/business',
              builder: (_, __) => const BusinessCenterScreen()),
          GoRoute(
              path: '/business/:id',
              builder: (_, state) => BusinessProfileScreen(
                  businessId: state.pathParameters['id']!)),
          GoRoute(
              path: '/business/post/create',
              builder: (_, __) => const CreateDiscoveryScreen()),
          GoRoute(
            path: '/chats',
            builder: (_, __) => const ConversationsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/activity/:id',
            builder: (_, state) => ActivityDetailsScreen(
              activityId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/activity/:id/edit',
            builder: (_, state) => EditActivityScreen(
              activityId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/activity/:id/participants',
            builder: (_, state) => ParticipantsScreen(
              activityId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/chat/:activityId',
            builder: (_, state) => GroupChatScreen(
              activityId: state.pathParameters['activityId']!,
            ),
          ),
          GoRoute(
            path: '/message/:userId',
            builder: (_, state) =>
                PrivateChatScreen(otherUserId: state.pathParameters['userId']!),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/profile/user/:userId',
            builder: (_, state) => PublicProfileScreen(
              userId: state.pathParameters['userId']!,
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/privacy',
            builder: (_, __) => const PrivacyScreen(),
          ),
          GoRoute(
            path: '/blocked-users',
            builder: (_, __) => const BlockedUsersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/filters',
        builder: (_, __) => const FiltersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
    ],
    errorBuilder: (
      context,
      state,
    ) =>
        Scaffold(
      body: Center(
        child: Text(
          'Tela não encontrada: ${state.uri}',
        ),
      ),
    ),
  );
});
