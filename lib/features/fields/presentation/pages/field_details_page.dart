import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/theme/app_theme.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/features/fields/data/models/field_model.dart';
import 'package:football/features/fields/presentation/providers/fields_providers.dart';
import 'package:football/core/routing/app_navigation.dart';
import 'package:go_router/go_router.dart';

class FieldDetailsPage extends ConsumerStatefulWidget {
  final String fieldId;
  final FieldModel? field;

  const FieldDetailsPage({super.key, required this.fieldId, this.field});

  @override
  ConsumerState<FieldDetailsPage> createState() => _FieldDetailsPageState();
}

class _FieldDetailsPageState extends ConsumerState<FieldDetailsPage> {
  final _pageCtrl = PageController(viewportFraction: 1.0);
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(fieldByIdProvider(widget.fieldId));
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Widget build(BuildContext context) {
    final fieldAsync = ref.watch(fieldByIdProvider(widget.fieldId));
    final resolvedField = fieldAsync.asData?.value ?? widget.field;

    if (resolvedField != null) {
      return _FieldDetailsScaffold(
        field: resolvedField,
        pageCtrl: _pageCtrl,
        pageIndex: _pageIndex,
        onPageChanged: (i) => setState(() => _pageIndex = i),
        onBack: () => context.safePop(),
        onRefresh: _refresh,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.safePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            tooltip: 'My Bookings',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.go('/my-bookings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: fieldAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 220),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 120),
              const Icon(Icons.error_outline, size: 52, color: Colors.red),
              const SizedBox(height: 10),
              const Text(
                'Failed to load field details',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                friendlyErrorMessage(e),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Center(
                child: AppButton(
                  text: 'Retry',
                  width: 140,
                  onPressed: () async {
                    ref.invalidate(fieldByIdProvider(widget.fieldId));
                    await Future<void>.delayed(
                      const Duration(seconds: 2),
                    );
                  },
                ),
              ),
            ],
          ),
          data: (field) => _FieldDetailsScaffold(
            field: field,
            pageCtrl: _pageCtrl,
            pageIndex: _pageIndex,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            onBack: () => context.safePop(),
            onRefresh: _refresh,
          ),
        ),
      ),
    );
  }
}

class _FieldDetailsScaffold extends StatelessWidget {
  final FieldModel field;
  final PageController pageCtrl;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;

  const _FieldDetailsScaffold({
    required this.field,
    required this.pageCtrl,
    required this.pageIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = (field.nameAr?.trim().isNotEmpty == true)
        ? field.nameAr!
        : field.name;

    final address = (field.addressAr?.trim().isNotEmpty == true)
        ? field.addressAr!
        : field.address;

    final desc = (field.descriptionAr?.trim().isNotEmpty == true)
        ? field.descriptionAr!
        : (field.description ?? '');

    final sortedImages = [...field.images]
      ..sort((a, b) => a.order.compareTo(b.order));

    final urls = sortedImages
        .map((e) => e.url.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            tooltip: 'My Bookings',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.go('/my-bookings'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: theme.dividerColor.withAlpha(120)),
            ),
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.push('/booking/choose-time/${field.id}');
              },
              child: const Text(
                'Book Now',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCarousel(
                    controller: pageCtrl,
                    urls: urls,
                    height: 190,
                    onPageChanged: onPageChanged,
                  ),
                  if (urls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: _Dots(count: urls.length, index: pageIndex),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (field.averageRating != null)
                          _RatingPill(
                            rating: field.averageRating!,
                            reviews: field.totalReviews,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.subText,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address.trim().isEmpty ? '—' : address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.subText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _priceText(field),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (desc.trim().isNotEmpty) ...[
              Text(
                'Description',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    desc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withAlpha(220),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Field Features',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const _FeatureRow(title: 'Synthetic grass'),
            const _FeatureRow(title: 'Changing rooms'),
            const _FeatureRow(title: 'Floodlights'),
            const SizedBox(height: 12),
            Text(
              'Location',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 140,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.green.withAlpha(36),
                            Colors.black.withAlpha(8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            size: 34,
                            color: Colors.black38,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Map preview\nlat: ${field.latitude.toStringAsFixed(4)}, lng: ${field.longitude.toStringAsFixed(4)}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Field ID: ${field.id}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCarousel extends StatelessWidget {
  final PageController controller;
  final List<String> urls;
  final double height;
  final ValueChanged<int> onPageChanged;

  const _HeroCarousel({
    required this.controller,
    required this.urls,
    required this.height,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.green.withAlpha(56), Colors.black.withAlpha(12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.sports_soccer, size: 48, color: Colors.black26),
        ),
      );
    }

    if (urls.length == 1) {
      return Image.network(
        urls.first,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.black.withAlpha(10),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 34,
              color: Colors.black38,
            ),
          ),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: controller,
        itemCount: urls.length,
        onPageChanged: onPageChanged,
        physics: const PageScrollPhysics(),
        pageSnapping: true,
        itemBuilder: (_, i) {
          return Image.network(
            urls[i],
            key: ValueKey('${urls[i]}_$i'),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black.withAlpha(10),
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 34,
                  color: Colors.black38,
                ),
              ),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: height,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          );
        },
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 18 : 6,
          decoration: BoxDecoration(
            color: active ? AppColors.green : AppColors.green.withAlpha(60),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  final int reviews;

  const _RatingPill({required this.rating, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.green.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, size: 16, color: AppColors.green),
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.green,
            ),
          ),
          if (reviews > 0) ...[
            const SizedBox(width: 6),
            Text(
              '($reviews)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String title;

  const _FeatureRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle, color: AppColors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

String _priceText(FieldModel f) {
  final price = f.basePrice;
  if (price == null) return '—';

  final formatted = price == price.truncateToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);

  return '$formatted EGP/hr';
}