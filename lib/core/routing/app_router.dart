import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/features/owner/presentation/pages/owner_booking_details_page.dart';
import 'package:football/features/owner/presentation/pages/owner_bulk_time_slots_page.dart';
import 'package:football/features/wallet/presentation/pages/wallet_top_up_page.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/data/models/admin_booking_model.dart';
import '../../features/admin/presentation/pages/admin_account_page.dart';
import '../../features/admin/presentation/pages/admin_booking_details_page.dart';
import '../../features/admin/presentation/pages/admin_bookings_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_fields_page.dart';
import '../../features/admin/presentation/pages/admin_payments_page.dart';
import '../../features/admin/presentation/pages/admin_payment_accounts_page.dart';
import '../../features/admin/presentation/pages/admin_platform_wallet_page.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/admin/presentation/pages/admin_users_page.dart';
import '../../features/admin/presentation/pages/admin_wallet_page.dart';
import '../../features/admin/presentation/pages/admin_withdrawal_requests_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/providers/auth_session_provider.dart';
import '../../features/bookings/data/models/booking_model.dart';
import '../../features/bookings/data/models/time_slot_model.dart';
import '../../features/bookings/presentation/pages/booking_confirmation_page.dart';
import '../../features/bookings/presentation/pages/booking_qr_page.dart';
import '../../features/bookings/presentation/pages/choose_time_page.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
import '../../features/fields/data/models/field_model.dart';
import '../../features/fields/presentation/pages/field_details_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/owner/presentation/pages/add_edit_time_slot_page.dart';
import '../../features/owner/presentation/pages/add_field_page.dart';
import '../../features/owner/presentation/pages/owner_bookings_page.dart';
import '../../features/owner/presentation/pages/owner_fields_page.dart';
import '../../features/owner/presentation/pages/owner_qr_checkin_page.dart';
import '../../features/owner/presentation/pages/owner_time_slots_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/wallet/presentation/pages/wallet_page.dart';
import 'app_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) => AppRouter.router(ref));

final routerRefreshProvider = Provider<ValueNotifier<int>>((ref) {
  final notifier = ValueNotifier<int>(0);

  ref.listen<AuthStatus>(authSessionProvider, (_, __) => notifier.value++);
  ref.listen<bool>(authIsVerifiedProvider, (_, __) => notifier.value++);
  ref.listen<AuthUser?>(authUserProvider, (_, __) => notifier.value++);

  ref.onDispose(notifier.dispose);
  return notifier;
});

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static GoRouter router(Ref ref) {
    final refreshListenable = ref.read(routerRefreshProvider);

    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: refreshListenable,
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('FootballBook')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Page Not Found\n\n${state.error ?? ''}\n\nLocation: ${state.uri}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      redirect: (context, state) {
        final authStatus = ref.read(authSessionProvider);
        final isVerified = ref.read(authIsVerifiedProvider);
        final email = ref.read(authEmailProvider);
        final authUser = ref.read(authUserProvider);
        final role = (authUser?.role ?? '').trim().toUpperCase();

        final loc = state.matchedLocation;

        final isSplash = loc == '/splash';
        final isLogin = loc == '/login';
        final isRegister = loc == '/register';
        final isForgot = loc == '/forgot-password';
        final isReset = loc == '/reset-password';
        final isVerify = loc == '/verify-email';

        final isOwnerRoot = loc == '/owner';
        final isOwnerBookings = loc == '/owner/bookings';
        final isOwnerBookingDetails = loc.startsWith('/owner/bookings/');
        final isOwnerAddField = loc == '/owner/add-field';
        final isOwnerEditField = loc == '/owner/edit-field';
        final isOwnerFieldSlots = loc == '/owner/field-slots';
        final isOwnerEditSlot = loc == '/owner/field-slots/edit';
        final isOwnerBulkSlots = loc == '/owner/field-slots/bulk';
        final isOwnerCheckIn = loc == '/owner/check-in';

        final isPlayerRoot = loc == '/home';
        final isPlayerBookings = loc == '/my-bookings';
        final isPlayerWallet = loc == '/wallet';
        final isSharedProfile = loc == '/profile';

        final isPlayerArea = isPlayerRoot || isPlayerBookings || isPlayerWallet;

        final isOwnerArea =
            isOwnerRoot ||
            isOwnerBookings ||
            isOwnerBookingDetails ||
            isOwnerAddField ||
            isOwnerEditField ||
            isOwnerFieldSlots ||
            isOwnerEditSlot ||
            isOwnerBulkSlots ||
            isOwnerCheckIn;

        if (loc == '/booking-confirmation' && state.extra == null) {
          return '/home';
        }

        if (loc.startsWith('/booking/') && loc.endsWith('/qr')) {
          final id = state.pathParameters['id'];
          if (id == null || id.trim().isEmpty) return '/my-bookings';
        }

        if (authStatus == AuthStatus.unknown) {
          return isSplash ? null : '/splash';
        }

        final isAuthed = authStatus == AuthStatus.authenticated;

        final isPublicAuthRoute =
            isSplash || isLogin || isRegister || isForgot || isReset || isVerify;

        if (!isAuthed) {
          return isPublicAuthRoute ? null : '/login';
        }

        if (isAuthed && !isVerified) {
          if (isVerify) return null;

          if (email != null && email.trim().isNotEmpty) {
            return '/verify-email?email=${Uri.encodeComponent(email.trim())}';
          }
          return '/verify-email';
        }

        if (isAuthed && isVerified) {
          if (isPublicAuthRoute) {
            if (role == 'ADMIN') return '/admin/dashboard';
            if (role == 'FIELD_OWNER') return '/owner';
            return '/home';
          }

          if (isSharedProfile) {
            return null;
          }

          if (role == 'ADMIN') {
            if (!loc.startsWith('/admin')) {
              return '/admin/dashboard';
            }
          }

          if (role == 'FIELD_OWNER') {
            if (isPlayerArea) return '/owner';
          }

          if (role != 'FIELD_OWNER' && role != 'ADMIN') {
            if (isOwnerArea || loc.startsWith('/admin')) {
              return '/home';
            }
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const SplashPage()),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const LoginPage()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const RegisterPage()),
        ),
        GoRoute(
          path: '/forgot-password',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const ForgotPasswordPage()),
        ),
        GoRoute(
          path: '/reset-password',
          pageBuilder: (context, state) {
            final extra = state.extra;
            String? email;
            String? otp;

            if (extra is Map<String, dynamic>) {
              email = extra['email']?.toString();
              otp = extra['otp']?.toString();
            } else if (extra is String) {
              email = extra;
            }

            return _buildPage(
              key: state.pageKey,
              child: ResetPasswordPage(
                email: email,
                otp: otp,
              ),
            );
          },
        ),
        GoRoute(
          path: '/admin/withdrawal-requests',
          pageBuilder: (context, state) => _buildPage(
            key: state.pageKey,
            child: const AdminWithdrawalRequestsPage(),
          ),
        ),
        GoRoute(
          path: '/admin/account',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminAccountPage()),
        ),
        GoRoute(
          path: '/verify-email',
          pageBuilder: (context, state) {
            final emailFromExtra = state.extra as String?;
            final emailFromQuery = state.uri.queryParameters['email'];

            return _buildPage(
              key: state.pageKey,
              child: VerifyEmailPage(
                email: emailFromExtra ?? emailFromQuery,
              ),
            );
          },
        ),
        GoRoute(
          path: '/admin',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminDashboardPage()),
        ),
        GoRoute(
          path: '/owner',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const OwnerFieldsPage()),
        ),
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminDashboardPage()),
        ),
        GoRoute(
          path: '/admin/users',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminUsersPage()),
        ),
        GoRoute(
          path: '/admin/fields',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminFieldsPage()),
        ),
        GoRoute(
          path: '/admin/bookings',
          pageBuilder: (context, state) {
            final initialSearch = state.uri.queryParameters['search'];
            return _buildPage(
              key: state.pageKey,
              child: AdminBookingsPage(initialSearch: initialSearch),
            );
          },
        ),
        GoRoute(
          path: '/admin/bookings/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final booking = state.extra is AdminBookingModel
                ? state.extra as AdminBookingModel
                : null;

            return _buildPage(
              key: state.pageKey,
              child: AdminBookingDetailsPage(
                bookingId: id,
                initialBooking: booking,
              ),
            );
          },
        ),
        GoRoute(
          path: '/admin/payments',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminPaymentsPage()),
        ),
        GoRoute(
          path: '/admin/payment-accounts',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminPaymentAccountsPage()),
        ),
        GoRoute(
          path: '/admin/settings',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminSettingsPage()),
        ),
        GoRoute(
          path: '/admin/wallet',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AdminWalletPage()),
        ),
        GoRoute(
          path: '/admin/platform-wallet',
          pageBuilder: (context, state) => _buildPage(
            key: state.pageKey,
            child: const AdminPlatformWalletPage(),
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/add-field',
          pageBuilder: (context, state) =>
              _buildPage(key: state.pageKey, child: const AddFieldPage()),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/edit-field',
          pageBuilder: (context, state) {
            final field = state.extra as FieldModel?;

            if (field == null) {
              return _buildPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field data')),
                ),
              );
            }

            return _buildPage(
              key: state.pageKey,
              child: AddFieldPage(field: field),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/field-slots',
          pageBuilder: (context, state) {
            final extra = state.extra;
            String? fieldId;
            String? fieldName;

            if (extra is Map) {
              fieldId = extra['fieldId']?.toString();
              fieldName = extra['fieldName']?.toString();
            }

            if (fieldId == null || fieldId.trim().isEmpty) {
              return _buildPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field id')),
                ),
              );
            }

            return _buildPage(
              key: state.pageKey,
              child: OwnerTimeSlotsPage(
                fieldId: fieldId,
                fieldName: (fieldName?.trim().isNotEmpty ?? false)
                    ? fieldName!.trim()
                    : 'Field Time Slots',
              ),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/field-slots/edit',
          pageBuilder: (context, state) {
            final extra = state.extra;

            String? fieldId;
            String? fieldName;
            DateTime? date;
            TimeSlotModel? slot;

            if (extra is Map) {
              fieldId = extra['fieldId']?.toString();
              fieldName = extra['fieldName']?.toString();
              date = extra['date'] as DateTime?;
              slot = extra['slot'] as TimeSlotModel?;
            }

            if ((fieldId == null || fieldId.trim().isEmpty) && slot == null) {
              return _buildPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field data')),
                ),
              );
            }

            return _buildPage(
              key: state.pageKey,
              child: AddEditTimeSlotPage(
                fieldId: fieldId ?? slot!.fieldId,
                fieldName: (fieldName?.trim().isNotEmpty ?? false)
                    ? fieldName!.trim()
                    : (slot?.field?.name ?? 'Field Time Slot'),
                slot: slot,
                initialDate: date,
              ),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/bookings',
          pageBuilder: (context, state) {
            final extra = state.extra;
            String? fieldId;
            String? fieldName;

            if (extra is Map) {
              fieldId = extra['fieldId']?.toString();
              fieldName = extra['fieldName']?.toString();
            }

            fieldId ??= state.uri.queryParameters['fieldId'];
            fieldName ??= state.uri.queryParameters['fieldName'];

            return _buildPage(
              key: state.pageKey,
              child: OwnerBookingsPage(fieldId: fieldId, fieldName: fieldName),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/bookings/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final booking = state.extra is BookingModel
                ? state.extra as BookingModel
                : null;

            return _buildPage(
              key: state.pageKey,
              child: OwnerBookingDetailsPage(
                bookingId: id,
                initialBooking: booking,
              ),
            );
          },
        ),
        GoRoute(
          path: '/wallet/top-up',
          builder: (context, state) => const WalletTopUpPage(),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/check-in',
          pageBuilder: (context, state) {
            final extra = state.extra;
            String? fieldId;
            String? fieldName;
            String? bookingId;
            String? qrToken;

            if (extra is Map) {
              fieldId = extra['fieldId']?.toString();
              fieldName = extra['fieldName']?.toString();
              bookingId = extra['bookingId']?.toString();
              qrToken = extra['qrToken']?.toString();
            }

            return _buildPage(
              key: state.pageKey,
              child: OwnerQrCheckInPage(
                fieldId: fieldId,
                fieldName: fieldName,
                initialBookingId: bookingId,
                initialQrToken: qrToken,
              ),
            );
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  pageBuilder: (context, state) =>
                      _buildPage(key: state.pageKey, child: const HomePage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/my-bookings',
                  pageBuilder: (context, state) => _buildPage(
                    key: state.pageKey,
                    child: const MyBookingsPage(),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/wallet',
                  pageBuilder: (context, state) =>
                      _buildPage(key: state.pageKey, child: const WalletPage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  pageBuilder: (context, state) => _buildPage(
                    key: state.pageKey,
                    child: const ProfilePage(),
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/field/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            final field = state.extra is FieldModel
                ? state.extra as FieldModel
                : null;

            return _buildPage(
              key: state.pageKey,
              child: FieldDetailsPage(fieldId: id, field: field),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/booking/choose-time',
          pageBuilder: (context, state) {
            final field = state.extra as FieldModel?;
            final child = (field == null)
                ? const Scaffold(
                    body: Center(child: Text('Missing field data')),
                  )
                : ChooseTimePage(field: field);

            return _buildPage(key: state.pageKey, child: child);
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/field-slots/bulk',
          pageBuilder: (context, state) {
            final extra = state.extra;

            if (extra is! Map<String, dynamic>) {
              return _buildPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing bulk time slots data')),
                ),
              );
            }

            final fieldId = extra['fieldId']?.toString();
            final fieldName = extra['fieldName']?.toString();

            if (fieldId == null || fieldId.trim().isEmpty) {
              return _buildPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field id')),
                ),
              );
            }

            return _buildPage(
              key: state.pageKey,
              child: OwnerBulkTimeSlotsPage(
                fieldId: fieldId,
                fieldName: (fieldName?.trim().isNotEmpty ?? false)
                    ? fieldName!.trim()
                    : 'Field Time Slots',
              ),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/booking-confirmation',
          pageBuilder: (context, state) {
            final args = state.extra as BookingConfirmationArgs?;
            return _buildPage(
              key: state.pageKey,
              child: BookingConfirmationPage(args: args),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/booking/:id/qr',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildPage(
              key: state.pageKey,
              child: BookingQrPage(bookingId: id),
            );
          },
        ),
      ],
    );
  }
}

CustomTransitionPage<void> _buildPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final offsetTween = Tween<Offset>(
        begin: const Offset(0.04, 0.0),
        end: Offset.zero,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: offsetTween.animate(curved),
          child: child,
        ),
      );
    },
  );
}