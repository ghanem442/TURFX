import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/network/providers.dart';
import 'package:football/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:football/features/bookings/data/models/booking_model.dart';
import 'package:football/features/owner/data/models/owner_fields_response_model.dart';
import 'package:football/features/owner/data/owner_repository.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return OwnerRepository(api);
});

final ownerMyFieldsProvider =
    FutureProvider<OwnerFieldsResponseModel>((ref) async {
  final repo = ref.watch(ownerRepositoryProvider);
  final user = ref.watch(authUserProvider);
  final currentUserId = user?.id?.trim() ?? '';

  final response = await repo.getMyFields(
    page: 1,
    limit: 20,
  );

  // Filter client-side: only show fields belonging to the current owner
  if (currentUserId.isNotEmpty) {
    final filtered = response.data
        .where((field) => field.ownerId == currentUserId)
        .toList();
    return OwnerFieldsResponseModel(
      success: response.success,
      data: filtered,
      meta: response.meta,
    );
  }

  return response;
});

final ownerBookingsProvider =
    StateNotifierProvider<OwnerBookingsNotifier, OwnerBookingsState>((ref) {
  final repo = ref.watch(ownerRepositoryProvider);
  return OwnerBookingsNotifier(repo);
});

class OwnerBookingsState {
  final List<BookingModel> bookings;
  final OwnerBookingsPagination? pagination;
  final String? selectedFieldId;
  final String? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final String? message;

  const OwnerBookingsState({
    this.bookings = const [],
    this.pagination,
    this.selectedFieldId,
    this.selectedStatus,
    this.startDate,
    this.endDate,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.message,
  });

  bool get hasBookings => bookings.isNotEmpty;
  bool get hasMore => pagination?.hasMore ?? false;
  int get currentPage => pagination?.page ?? 1;

  OwnerBookingsState copyWith({
    List<BookingModel>? bookings,
    Object? pagination = _sentinel,
    Object? selectedFieldId = _sentinel,
    Object? selectedStatus = _sentinel,
    Object? startDate = _sentinel,
    Object? endDate = _sentinel,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    Object? error = _sentinel,
    Object? message = _sentinel,
  }) {
    return OwnerBookingsState(
      bookings: bookings ?? this.bookings,
      pagination: identical(pagination, _sentinel)
          ? this.pagination
          : pagination as OwnerBookingsPagination?,
      selectedFieldId: identical(selectedFieldId, _sentinel)
          ? this.selectedFieldId
          : selectedFieldId as String?,
      selectedStatus: identical(selectedStatus, _sentinel)
          ? this.selectedStatus
          : selectedStatus as String?,
      startDate: identical(startDate, _sentinel)
          ? this.startDate
          : startDate as DateTime?,
      endDate:
          identical(endDate, _sentinel) ? this.endDate : endDate as DateTime?,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error as String?,
      message:
          identical(message, _sentinel) ? this.message : message as String?,
    );
  }

  static const _sentinel = Object();
}

class OwnerBookingsNotifier extends StateNotifier<OwnerBookingsState> {
  final OwnerRepository _repo;

  OwnerBookingsNotifier(this._repo) : super(const OwnerBookingsState());

  Future<void> loadBookings({
    String? fieldId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool refresh = false,
    int limit = 10,
  }) async {
    final resolvedFieldId = fieldId ?? state.selectedFieldId;
    final resolvedStatus = status ?? state.selectedStatus;
    final resolvedStartDate = startDate ?? state.startDate;
    final resolvedEndDate = endDate ?? state.endDate;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      isLoadingMore: false,
      error: null,
      message: null,
      selectedFieldId: resolvedFieldId,
      selectedStatus: resolvedStatus,
      startDate: resolvedStartDate,
      endDate: resolvedEndDate,
      bookings: refresh ? <BookingModel>[] : state.bookings,
      pagination: refresh ? null : state.pagination,
    );

    try {
      final result = await _repo.getOwnerBookings(
        fieldId: resolvedFieldId,
        status: resolvedStatus,
        startDate: resolvedStartDate,
        endDate: resolvedEndDate,
        page: 1,
        limit: limit,
      );

      state = state.copyWith(
        bookings: result.bookings,
        pagination: result.pagination,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: null,
        message: result.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore({int limit = 10}) async {
    if (state.isLoading || state.isRefreshing || state.isLoadingMore) return;
    if (!(state.pagination?.hasMore ?? false)) return;

    state = state.copyWith(
      isLoadingMore: true,
      error: null,
    );

    try {
      final nextPage = (state.pagination?.page ?? 1) + 1;

      final result = await _repo.getOwnerBookings(
        fieldId: state.selectedFieldId,
        status: state.selectedStatus,
        startDate: state.startDate,
        endDate: state.endDate,
        page: nextPage,
        limit: limit,
      );

      state = state.copyWith(
        bookings: [...state.bookings, ...result.bookings],
        pagination: result.pagination,
        isLoadingMore: false,
        error: null,
        message: result.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await loadBookings(
      fieldId: state.selectedFieldId,
      status: state.selectedStatus,
      startDate: state.startDate,
      endDate: state.endDate,
      refresh: true,
    );
  }

  Future<void> forceRefresh() async {
    await loadBookings(
      fieldId: state.selectedFieldId,
      status: state.selectedStatus,
      startDate: state.startDate,
      endDate: state.endDate,
      refresh: true,
    );
  }

  Future<void> initialize({
    String? fieldId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(
      selectedFieldId: fieldId,
      selectedStatus: status,
      startDate: startDate,
      endDate: endDate,
    );

    await loadBookings(
      fieldId: fieldId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      refresh: true,
    );
  }

  Future<void> setFieldFilter(String? fieldId) async {
    state = state.copyWith(selectedFieldId: fieldId);

    await loadBookings(
      fieldId: fieldId,
      status: state.selectedStatus,
      startDate: state.startDate,
      endDate: state.endDate,
      refresh: true,
    );
  }

  Future<void> setStatusFilter(String? status) async {
    state = state.copyWith(selectedStatus: status);

    await loadBookings(
      fieldId: state.selectedFieldId,
      status: status,
      startDate: state.startDate,
      endDate: state.endDate,
      refresh: true,
    );
  }

  Future<void> setDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = state.copyWith(
      startDate: startDate,
      endDate: endDate,
    );

    await loadBookings(
      fieldId: state.selectedFieldId,
      status: state.selectedStatus,
      startDate: startDate,
      endDate: endDate,
      refresh: true,
    );
  }

  Future<void> clearFilters() async {
    state = state.copyWith(
      selectedFieldId: null,
      selectedStatus: null,
      startDate: null,
      endDate: null,
      bookings: const [],
      pagination: null,
      error: null,
      message: null,
    );

    await loadBookings(
      fieldId: null,
      status: null,
      startDate: null,
      endDate: null,
      refresh: true,
    );
  }
}