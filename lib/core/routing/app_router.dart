import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/features/owner/presentation/pages/owner_booking_details_page.dart';
import 'package:football/features/owner/presentation/pages/owner_bulk_time_slots_page.dart';
import 'package:football/features/wallet/presentation/pages/wallet_top_up_page.dart';
import 'package:go_router/go_router.dart';

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
import '../../features/bookings/presentation/pages/booking_confirmation_page.dart';
import 'router_refresh.dart';
import '../../features/bookings/presentation/pages/booking_qr_page.dart';
import '../../features/bookings/presentation/pages/choose_time_page.dart';
import '../../features/bookings/presentation/pages/my_bookings_page.dart';
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
import 'page_transitions.dart';
import 'app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.read(routerRefreshProvider);

  final router = GoRouter(
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
        final isOwnerWallet = loc == '/owner/wallet';

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
            isOwnerCheckIn ||
            isOwnerWallet;

        if (loc == '/booking-confirmation') {
          final extra = state.extra;
          final bookingId = extra is Map ? extra['bookingId']?.toString() : null;
          if (bookingId == null || bookingId.trim().isEmpty) {
            return '/home';
          }
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
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            child: const SplashPage(),
          ),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            style: AppTransitionStyle.fade,
            child: const LoginPage(),
          ),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const RegisterPage()),
        ),
        GoRoute(
          path: '/forgot-password',
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            child: const ForgotPasswordPage(),
          ),
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

            return buildAppPage(
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
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            child: const AdminWithdrawalRequestsPage(),
          ),
        ),
        GoRoute(
          path: '/admin/account',
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            child: const AdminAccountPage(),
          ),
        ),
        GoRoute(
          path: '/verify-email',
          pageBuilder: (context, state) {
            final emailFromExtra = state.extra as String?;
            final emailFromQuery = state.uri.queryParameters['email'];

            return buildAppPage(
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
              buildAppPage(key: state.pageKey, child: const AdminDashboardPage()),
        ),
        GoRoute(
          path: '/owner',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const OwnerFieldsPage()),
        ),
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminDashboardPage()),
        ),
        GoRoute(
          path: '/admin/users',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminUsersPage()),
        ),
        GoRoute(
          path: '/admin/fields',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminFieldsPage()),
        ),
        GoRoute(
          path: '/admin/bookings',
          pageBuilder: (context, state) {
            final initialSearch = state.uri.queryParameters['search'];
            return buildAppPage(
              key: state.pageKey,
              child: AdminBookingsPage(initialSearch: initialSearch),
            );
          },
        ),
        GoRoute(
          path: '/admin/bookings/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return buildAppPage(
              key: state.pageKey,
              child: AdminBookingDetailsPage(
                bookingId: id,
              ),
            );
          },
        ),
        GoRoute(
          path: '/admin/payments',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminPaymentsPage()),
        ),
        GoRoute(
          path: '/admin/payment-accounts',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminPaymentAccountsPage()),
        ),
        GoRoute(
          path: '/admin/settings',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminSettingsPage()),
        ),
        GoRoute(
          path: '/admin/wallet',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AdminWalletPage()),
        ),
        GoRoute(
          path: '/admin/platform-wallet',
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            child: const AdminPlatformWalletPage(),
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/add-field',
          pageBuilder: (context, state) =>
              buildAppPage(key: state.pageKey, child: const AddFieldPage()),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/edit-field',
          pageBuilder: (context, state) {
            final fieldId = state.uri.queryParameters['fieldId'];

            if (fieldId == null || fieldId.trim().isEmpty) {
              return buildAppPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field id')),
                ),
              );
            }

            return buildAppPage(
              key: state.pageKey,
              child: AddFieldPage(fieldId: fieldId),
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
              return buildAppPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field id')),
                ),
              );
            }

            return buildAppPage(
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
            Map<String, dynamic>? slotData;

            if (extra is Map) {
              fieldId = extra['fieldId']?.toString();
              fieldName = extra['fieldName']?.toString();
              date = extra['date'] as DateTime?;
              final rawSlot = extra['slot'];
              if (rawSlot is Map) {
                slotData = Map<String, dynamic>.from(rawSlot);
              }
            }

            if ((fieldId == null || fieldId.trim().isEmpty) && slotData == null) {
              return buildAppPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field data')),
                ),
              );
            }

            return buildAppPage(
              key: state.pageKey,
              child: AddEditTimeSlotPage(
                fieldId: fieldId ?? slotData!['fieldId']?.toString() ?? '',
                fieldName: (fieldName?.trim().isNotEmpty ?? false)
                    ? fieldName!.trim()
                    : 'Field Time Slot',
                slotData: slotData,
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

            return buildAppPage(
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
            return buildAppPage(
              key: state.pageKey,
              child: OwnerBookingDetailsPage(
                bookingId: id,
              ),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/wallet/top-up',
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            style: AppTransitionStyle.modal,
            child: const WalletTopUpPage(),
          ),
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/wallet',
          pageBuilder: (context, state) => buildAppPage(
            key: state.pageKey,
            style: AppTransitionStyle.modal,
            child: const WalletPage(),
          ),
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

            return buildAppPage(
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
                      buildAppPage(key: state.pageKey, child: const HomePage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/my-bookings',
                  pageBuilder: (context, state) => buildAppPage(
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
                      buildAppPage(key: state.pageKey, child: const WalletPage()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  pageBuilder: (context, state) => buildAppPage(
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
            return buildAppPage(
              key: state.pageKey,
              style: AppTransitionStyle.modal,
              child: FieldDetailsPage(fieldId: id),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/booking/choose-time/:fieldId',
          pageBuilder: (context, state) {
            final fieldId = state.pathParameters['fieldId'];
            final child = (fieldId == null || fieldId.trim().isEmpty)
                ? const Scaffold(
                    body: Center(child: Text('Missing field data')),
                  )
                : ChooseTimePage(fieldId: fieldId);

            return buildAppPage(
              key: state.pageKey,
              style: AppTransitionStyle.modal,
              child: child,
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/owner/field-slots/bulk',
          pageBuilder: (context, state) {
            final extra = state.extra;

            if (extra is! Map<String, dynamic>) {
              return buildAppPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing bulk time slots data')),
                ),
              );
            }

            final fieldId = extra['fieldId']?.toString();
            final fieldName = extra['fieldName']?.toString();

            if (fieldId == null || fieldId.trim().isEmpty) {
              return buildAppPage(
                key: state.pageKey,
                child: const Scaffold(
                  body: Center(child: Text('Missing field id')),
                ),
              );
            }

            return buildAppPage(
              key: state.pageKey,
              child: OwnerBulkTimeSlotsPage(
                fieldId: fieldId,
                fieldName: (fieldName?.trim().isNotEmpty ?? false)
                    ? fieldName!.trim()
                    : 'Field Time Slots',
                selectedDate: extra['selectedDate'] as DateTime?,
              ),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/booking-confirmation',
          pageBuilder: (context, state) {
            final args = state.extra is Map<String, dynamic>
                ? state.extra as Map<String, dynamic>
                : null;
            return buildAppPage(
              key: state.pageKey,
              style: AppTransitionStyle.modal,
              child: BookingConfirmationPage(args: args),
            );
          },
        ),
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/booking/:id/qr',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return buildAppPage(
              key: state.pageKey,
              style: AppTransitionStyle.modal,
              child: BookingQrPage(bookingId: id),
            );
          },
        ),
      ],
    );

    ref.onDispose(router.dispose);
    return router;
  });