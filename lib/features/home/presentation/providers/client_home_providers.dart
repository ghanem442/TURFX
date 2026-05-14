import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/user_location_resolver.dart';
import '../../../fields/data/models/field_model.dart';
import '../../../fields/presentation/providers/fields_providers.dart';

/// Device (or fallback) coordinates for client-side "nearby fields" search.
final resolvedSearchLocationProvider = FutureProvider<GeoSearchParams>(
  (ref) => resolveGeoSearchParams(),
);

final clientSearchQueryProvider = StateProvider<String>((ref) => '');

final clientFieldsProvider = FutureProvider<List<FieldModel>>((ref) async {
  final repo = ref.read(fieldsRepositoryProvider);
  final geo = await ref.watch(resolvedSearchLocationProvider.future);

  final res = await repo.searchFields(
    latitude: geo.latitude,
    longitude: geo.longitude,
    radiusKm: geo.radiusKm,
  );

  return res.data;
});

final clientFilteredFieldsProvider = Provider<AsyncValue<List<FieldModel>>>((ref) {
  final q = ref.watch(clientSearchQueryProvider).trim().toLowerCase();
  final asyncFields = ref.watch(clientFieldsProvider);

  return asyncFields.whenData((fields) {
    if (q.isEmpty) return fields;

    return fields.where((f) {
      final name = f.name.toLowerCase();
      final address = f.address.toLowerCase();
      return name.contains(q) || address.contains(q);
    }).toList();
  });
});
