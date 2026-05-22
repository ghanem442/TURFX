import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/network/media_url.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/booking_model.dart';
import '../providers/booking_providers.dart';

class BookingQrPage extends ConsumerWidget {
  final String bookingId;

  const BookingQrPage({
    super.key,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingByIdProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(bookingByIdProvider(bookingId));
              ref.invalidate(bookingQrProvider(bookingId));
            },
          ),
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: SafeArea(
        child: bookingAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (e, _) => _BookingQrMessageState(
            icon: Icons.error_outline,
            title: 'Could not load booking details',
            message: _friendlyBookingError(e),
            primaryAction: FilledButton.icon(
              onPressed: () => ref.invalidate(bookingByIdProvider(bookingId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            secondaryAction: OutlinedButton.icon(
              onPressed: () => context.go('/my-bookings'),
              icon: const Icon(Icons.list_alt),
              label: const Text('Back to My Bookings'),
            ),
          ),
          data: (booking) {
            final eligibility = ref.watch(bookingQrEligibilityProvider(booking));

            if (!eligibility.canShowQr) {
              return _BookingQrMessageState(
                icon: _iconForBookingStatus(booking),
                title: _titleForBookingStatus(booking),
                message: eligibility.message,
                infoCard: _BookingSummaryCard(booking: booking),
                primaryAction: FilledButton.icon(
                  onPressed: () => context.go('/my-bookings'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Back to My Bookings'),
                ),
                secondaryAction: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(bookingByIdProvider(bookingId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              );
            }

            final qrAsync = ref.watch(bookingQrProvider(bookingId));

            return qrAsync.when(
              loading: () => Column(
                children: [
                  _BookingHeaderCard(booking: booking),
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
              ),
              error: (e, _) => _BookingQrMessageState(
                icon: Icons.qr_code_2,
                title: 'QR could not be loaded',
                message: booking.isConfirmed || booking.isCheckedInStatus
                    ? 'Your booking is confirmed, but the QR could not be loaded right now. ${_friendlyQrError(e)}'
                    : _friendlyQrError(e),
                infoCard: _BookingSummaryCard(booking: booking),
                primaryAction: FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(bookingByIdProvider(bookingId));
                    ref.invalidate(bookingQrProvider(bookingId));
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                secondaryAction: OutlinedButton.icon(
                  onPressed: () => context.go('/my-bookings'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('Back to My Bookings'),
                ),
              ),
              data: (qr) {
                final rawUrl = qr.imageUrl.trim();
                final url = _normalizeQrUrl(rawUrl);
                final isUsed = booking.isCheckedInStatus || booking.qrIsUsed || qr.isUsed;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BookingHeaderCard(booking: booking),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: url.isEmpty
                              ? _qrFallbackBox(
                                  message:
                                      'QR image is not available right now.',
                                )
                              : Image.network(
                                  url,
                                  height: 260,
                                  width: 260,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) {
                                    return _qrFallbackBox(
                                      message:
                                          'QR image could not be loaded.',
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        isUsed
                            ? 'This QR has already been used.'
                            : 'Show this QR to the owner عند الوصول للملعب',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Booking Number',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(booking.bookingNumberDisplay),
                            const SizedBox(height: 12),
                            const Text(
                              'Booking Status',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(_labelForBookingStatus(booking)),
                            const SizedBox(height: 12),
                            const Text(
                              'QR Status',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            Text(isUsed ? 'Used' : 'Ready'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text(
                                  'Used: ',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(isUsed ? 'YES' : 'NO'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/my-bookings'),
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Back to My Bookings'),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _normalizeQrUrl(String raw) {
    return resolvePublicMediaUrl(raw);
  }

  static Widget _qrFallbackBox({required String message}) {
    return SizedBox(
      height: 260,
      width: 260,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2, size: 56),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyQrError(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty) {
      return 'Please try again in a moment.';
    }
    if (text.contains('404')) {
      return 'QR record was not found.';
    }
    return text;
  }

  static String _friendlyBookingError(Object e) {
    final text = e.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty) {
      return 'Please try again in a moment.';
    }
    if (text.contains('404')) {
      return 'Booking was not found.';
    }
    return text;
  }

  static IconData _iconForBookingStatus(BookingModel booking) {
    if (booking.isPendingPayment) return Icons.pending_actions;
    if (booking.statusUpper == 'PAYMENT_FAILED') return Icons.cancel_outlined;
    if (booking.isCancelled) return Icons.event_busy;
    if (booking.isPlayed) return Icons.sports_soccer;
    if (booking.statusUpper == 'NO_SHOW' ||
        booking.statusUpper == 'EXPIRED_NO_SHOW') {
      return Icons.timer_off;
    }
    return Icons.info_outline;
  }

  static String _titleForBookingStatus(BookingModel booking) {
    if (booking.isPendingPayment) {
      return 'QR not available yet';
    }
    if (booking.statusUpper == 'PAYMENT_FAILED') {
      return 'Booking was not confirmed';
    }
    if (booking.isCancelled) {
      return 'Booking cancelled';
    }
    if (booking.isPlayed) {
      return 'Booking completed';
    }
    if (booking.statusUpper == 'NO_SHOW' ||
        booking.statusUpper == 'EXPIRED_NO_SHOW') {
      return 'Booking is no longer active';
    }
    return 'QR not available';
  }

  static String _labelForBookingStatus(BookingModel booking) {
    switch (booking.statusUpper) {
      case 'PENDING_PAYMENT':
        return 'Pending payment';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'CHECKED_IN':
        return 'Checked in';
      case 'COMPLETED':
        return 'Completed';
      case 'PLAYED':
        return 'Played';
      case 'NO_SHOW':
        return 'No show';
      case 'EXPIRED_NO_SHOW':
        return 'Expired no show';
      case 'PAYMENT_FAILED':
        return 'Payment failed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'CANCELLED_REFUNDED':
        return 'Cancelled (refunded)';
      case 'CANCELLED_NO_REFUND':
        return 'Cancelled (no refund)';
      default:
        return booking.status;
    }
  }
}

class _BookingQrMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? infoCard;
  final Widget primaryAction;
  final Widget? secondaryAction;

  const _BookingQrMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryAction,
    this.infoCard,
    this.secondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.orange),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (infoCard != null) ...[
              const SizedBox(height: 16),
              infoCard!,
            ],
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: primaryAction),
            if (secondaryAction != null) ...[
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: secondaryAction),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingHeaderCard extends StatelessWidget {
  final BookingModel booking;

  const _BookingHeaderCard({
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.fieldDisplayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              booking.bookingNumberDisplay,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final BookingModel booking;

  const _BookingSummaryCard({
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Summary',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text('Field: ${booking.fieldDisplayName}'),
            const SizedBox(height: 4),
            Text('Booking: ${booking.bookingNumberDisplay}'),
            const SizedBox(height: 4),
            Text('Status: ${BookingQrPage._labelForBookingStatus(booking)}'),
          ],
        ),
      ),
    );
  }
}