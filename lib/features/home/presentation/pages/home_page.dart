import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:football/core/theme/app_theme.dart';
import 'package:football/core/utils/error_utils.dart';
import 'package:football/core/widgets/app_button.dart';
import 'package:football/core/widgets/fade_slide_in.dart';
import 'package:football/core/theme/theme_mode_provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'package:football/features/fields/data/models/field_model.dart';
import 'package:football/features/fields/presentation/providers/fields_providers.dart';
import 'package:football/core/services/welcome_service.dart';
import 'package:football/features/auth/presentation/providers/auth_session_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchCtrl = TextEditingController();
  bool _welcomeShown = false;

  @override
  void initState() {
    super.initState();
    
    // Show welcome animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWelcomeIfNeeded();
      
      // Delay fields fetch to allow router to stabilize after login
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          ref.read(fieldsProvider);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showWelcomeIfNeeded() async {
    // Prevent multiple calls
    if (_welcomeShown) return;
    _welcomeShown = true;

    // Get current user
    final user = ref.read(authUserProvider);

    // Show welcome if user is logged in
    if (user != null && mounted) {
      final ctx = context;
      await WelcomeService.showWelcomeAnimation(
        ctx,
        userName: user.name ?? 'User',
        userRole: user.role ?? 'PLAYER',
      );
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(fieldsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Widget build(BuildContext context) {
    // Don't watch immediately - let initState handle the delayed fetch
    final fieldsAsync = ref.watch(fieldsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeModeProvider);
              return IconButton(
                tooltip: AppLocalizations.of(context)!.toggleTheme,
                icon: Icon(
                  mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                ),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
              );
            },
          ),
        ],
      ),
      body: fieldsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 52, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load fields',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _friendlyError(err),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Try Again',
                  icon: Icons.refresh,
                  width: 200,
                  onPressed: _refresh,
                ),
              ],
            ),
          ),
        ),
        data: (fields) {
          final q = _searchCtrl.text.trim().toLowerCase();

          final filtered = q.isEmpty
              ? fields
              : fields.where((f) {
                  final name = (f.nameAr ?? f.name).toLowerCase();
                  final address =
                      (f.addressAr ?? f.address).toLowerCase();
                  return name.contains(q) || address.contains(q);
                }).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: const InputDecoration(
                          hintText: 'Search for a field',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 44,
                      width: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => FocusScope.of(context).unfocus(),
                        child: const Icon(Icons.search),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty) ...[
                  const SizedBox(height: 140),
                  const Center(child: Text('No fields found')),
                ] else ...[
                  FadeSlideIn(
                    index: 0,
                    child: _BigFieldCard(
                      field: filtered.first,
                      onTap: () => context.push(
                        '/field/${filtered.first.id}',
                        extra: filtered.first,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      final items = filtered.skip(1).toList();
                      if (items.isEmpty) return const SizedBox.shrink();

                      final isTwoCols = c.maxWidth >= 520;

                      if (!isTwoCols) {
                        return Column(
                          children: items
                              .take(6)
                              .map(
                                (f) {
                                  final i = items.indexOf(f) + 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: FadeSlideIn(
                                      index: i,
                                      child: _SmallFieldCard(
                                        field: f,
                                        onTap: () => context.push(
                                          '/field/${f.id}',
                                          extra: f,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                              .toList(),
                        );
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length.clamp(0, 6),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.15,
                            ),
                        itemBuilder: (context, i) {
                          final f = items[i];
                          return FadeSlideIn(
                            index: i + 1,
                            child: _SmallFieldCard(
                              field: f,
                              onTap: () =>
                                  context.push('/field/${f.id}'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BigFieldCard extends StatefulWidget {
  final FieldModel field;
  final VoidCallback onTap;

  const _BigFieldCard({required this.field, required this.onTap});

  @override
  State<_BigFieldCard> createState() => _BigFieldCardState();
}

class _BigFieldCardState extends State<_BigFieldCard> {
  int _pageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;

    final title = (field.nameAr?.trim().isNotEmpty == true)
        ? field.nameAr!
        : field.name;
    final subtitle = (field.addressAr?.trim().isNotEmpty == true)
        ? field.addressAr!
        : field.address;

    final imageUrls = field.images
        .map((e) => e.url)
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeFieldCarousel(
              urls: imageUrls,
              height: 170,
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
            ),
            if (imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Dots(count: imageUrls.length, index: _pageIndex),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _priceText(field),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      subtitle.trim().isEmpty ? '—' : subtitle,
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
          ],
        ),
      ),
    );
  }
}

class _SmallFieldCard extends StatefulWidget {
  final FieldModel field;
  final VoidCallback onTap;

  const _SmallFieldCard({required this.field, required this.onTap});

  @override
  State<_SmallFieldCard> createState() => _SmallFieldCardState();
}

class _SmallFieldCardState extends State<_SmallFieldCard> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final field = widget.field;

    final title = (field.nameAr?.trim().isNotEmpty == true)
        ? field.nameAr!
        : field.name;

    final imageUrls = field.images
        .map((e) => e.url)
        .where((e) => e.trim().isNotEmpty)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SmallFieldCarousel(
              urls: imageUrls,
              height: 110,
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
            ),
            if (imageUrls.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _Dots(count: imageUrls.length, index: _pageIndex),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _priceText(field),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeFieldCarousel extends StatelessWidget {
  final List<String> urls;
  final double height;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  const _HomeFieldCarousel({
    required this.urls,
    required this.height,
    required this.controller,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return _placeholder(height);
    }

    if (urls.length == 1) {
      return Image.network(
        urls.first,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _placeholder(height),
        loadingBuilder: (context, child, progress) {
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
        itemBuilder: (context, index) {
          return Image.network(
            urls[index],
            key: ValueKey('${urls[index]}_$index'),
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholder(height),
            loadingBuilder: (context, child, progress) {
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

  Widget _placeholder(double h) {
    return Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.green.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.sports_soccer, size: 44)),
    );
  }
}

class _SmallFieldCarousel extends StatelessWidget {
  final List<String> urls;
  final double height;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  const _SmallFieldCarousel({
    required this.urls,
    required this.height,
    required this.controller,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return _placeholder(height);
    }

    if (urls.length == 1) {
      return Image.network(
        urls.first,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _placeholder(height),
        loadingBuilder: (context, child, progress) {
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
        itemBuilder: (context, index) {
          return Image.network(
            urls[index],
            key: ValueKey('${urls[index]}_$index'),
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _placeholder(height),
            loadingBuilder: (context, child, progress) {
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

  Widget _placeholder(double h) {
    return Container(
      height: h,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.green.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: Icon(Icons.sports_soccer, size: 44)),
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
            color: active
                ? AppColors.green
                : AppColors.green.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
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

String _friendlyError(Object e) {
  final text = e.toString().toLowerCase();
  if (text.contains('timeout') || text.contains('socket')) {
    return 'انتهت مهلة الاتصال. تأكد من الإنترنت وحاول مرة أخرى.';
  }
  if (text.contains('connection refused') || text.contains('unable to resolve')) {
    return 'لا يمكن الوصول للسيرفر. تأكد من الاتصال.';
  }
  return friendlyErrorMessage(
    e,
    fallback: 'تعذر تحميل الملاعب',
  );
}