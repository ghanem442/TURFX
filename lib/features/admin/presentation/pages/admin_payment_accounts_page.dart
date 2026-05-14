import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/payment_account_model.dart';
import '../providers/payment_accounts_provider.dart';

class AdminPaymentAccountsPage extends ConsumerWidget {
  const AdminPaymentAccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.isLoading
                ? null
                : () => ref.read(paymentAccountsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (state.isLoading && state.accounts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 52),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load payment accounts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(paymentAccountsProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withAlpha(55)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'أضف أرقام الدفع اليدوي التي سيحول عليها اللاعبون. هذه الأرقام ستظهر للاعبين عند الحجز.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...state.accounts.values.map((account) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _PaymentAccountCard(
                    account: account,
                    onEdit: () => _showEditDialog(context, ref, account),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    PaymentAccountModel account,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditAccountDialog(account: account),
    );
  }
}

class _PaymentAccountCard extends StatelessWidget {
  final PaymentAccountModel account;
  final VoidCallback onEdit;

  const _PaymentAccountCard({
    required this.account,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gatewayLabel(account.gateway),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(isEnabled: account.isEnabled),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.phone_outlined,
              title: 'رقم الموبايل',
              value: account.mobileNumber.trim().isEmpty
                  ? 'غير محدد'
                  : account.mobileNumber.trim(),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.person_outline,
              title: 'اسم الحساب',
              value: account.accountName.trim().isEmpty
                  ? 'غير محدد'
                  : account.accountName.trim(),
            ),
            if (account.instructionsAr.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.info_outline,
                title: 'التعليمات (عربي)',
                value: account.instructionsAr.trim(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _gatewayLabel(String gateway) {
    switch (gateway.toUpperCase()) {
      case 'VODAFONE_CASH':
        return 'فودافون كاش';
      case 'INSTAPAY':
        return 'إنستا باي';
      default:
        return gateway;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isEnabled;

  const _StatusBadge({required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    final color = isEnabled ? Colors.green : Colors.grey;
    final bg = color.withAlpha(30);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isEnabled ? 'مفعل' : 'معطل',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditAccountDialog extends ConsumerStatefulWidget {
  final PaymentAccountModel account;

  const _EditAccountDialog({required this.account});

  @override
  ConsumerState<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<_EditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mobileController;
  late final TextEditingController _nameController;
  late final TextEditingController _instructionsArController;
  late final TextEditingController _instructionsEnController;
  late bool _isEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(text: widget.account.mobileNumber);
    _nameController = TextEditingController(text: widget.account.accountName);
    _instructionsArController =
        TextEditingController(text: widget.account.instructionsAr);
    _instructionsEnController =
        TextEditingController(text: widget.account.instructionsEn);
    _isEnabled = widget.account.isEnabled;
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _instructionsArController.dispose();
    _instructionsEnController.dispose();
    super.dispose();
  }

  String? _validateMobile(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'رقم الموبايل مطلوب';
    if (text.length < 11) return 'رقم الموبايل يجب أن يكون 11 رقم على الأقل';
    return null;
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'اسم الحساب مطلوب';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final updatedAccount = widget.account.copyWith(
        mobileNumber: _mobileController.text.trim(),
        accountName: _nameController.text.trim(),
        instructionsAr: _instructionsArController.text.trim(),
        instructionsEn: _instructionsEnController.text.trim(),
        isEnabled: _isEnabled,
      );

      await ref.read(paymentAccountsProvider.notifier).saveAccount(updatedAccount);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تعديل ${_gatewayLabel(widget.account.gateway)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  title: const Text('تفعيل طريقة الدفع'),
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الموبايل',
                    hintText: '01xxxxxxxxx',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateMobile,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحساب',
                    hintText: 'اسم صاحب الحساب',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsArController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'التعليمات (عربي)',
                    hintText: 'تعليمات للاعب بالعربي',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsEnController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'التعليمات (إنجليزي)',
                    hintText: 'Instructions for player in English',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('حفظ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _gatewayLabel(String gateway) {
    switch (gateway.toUpperCase()) {
      case 'VODAFONE_CASH':
        return 'فودافون كاش';
      case 'INSTAPAY':
        return 'إنستا باي';
      default:
        return gateway;
    }
  }
}
