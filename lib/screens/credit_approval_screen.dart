import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proplay/bloc/credit_approval/credit_approval_cubit.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/theme/app_colors.dart';

class CreditApprovalScreen extends StatelessWidget {
  const CreditApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CreditApprovalCubit(CreditHistoryService())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Aprobar saldo')),
        body: BlocConsumer<CreditApprovalCubit, CreditApprovalState>(
          listenWhen: (_, s) => s.message != null,
          listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.message!),
              backgroundColor: s.isError ? AppColors.error : null,
            ),
          ),
          builder: (context, s) {
            final cubit = context.read<CreditApprovalCubit>();
            if (s.items.isEmpty && s.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: s.items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 160),
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppColors.muted,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay solicitudes pendientes',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: s.items.length,
                      itemBuilder: (context, i) => _PurchaseCard(
                        item: s.items[i],
                        busy: s.busyId == s.items[i].$1.id,
                        locked: s.busyId != null,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PendingPurchase item;
  final bool busy;
  final bool locked;

  const _PurchaseCard({
    required this.item,
    required this.busy,
    required this.locked,
  });

  Future<void> _confirm(BuildContext context, {required bool approve}) async {
    final (entry, user) = item;
    final amount = UserModel.formatCredits(entry.creditAmount);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(approve ? 'Aprobar saldo' : 'Rechazar solicitud'),
        content: Text(
          approve
              ? 'Se acreditarán S/ $amount de saldo a ${user.fullName}. '
                    'Confirma que el pago de '
                    'S/ ${entry.amountPaid.toStringAsFixed(2)} llegó a Yape.'
              : 'No se acreditará saldo a ${user.fullName}. '
                    'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            style: approve
                ? null
                : TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(approve ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<CreditApprovalCubit>().review(item, approve: approve);
    }
  }

  Future<void> _openReceipt(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el recibo'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (entry, user) = item;
    final theme = Theme.of(context);
    final initials = [
      user.firstName,
      user.lastName,
    ].where((n) => n.isNotEmpty).map((n) => n[0]).join().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: theme.textTheme.titleMedium),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _DetailRow(
              icon: Icons.account_balance_wallet,
              label: 'Saldo',
              value: 'S/ ${UserModel.formatCredits(entry.creditAmount)}',
            ),
            _DetailRow(
              icon: Icons.payments,
              label: 'Pagó',
              value: 'S/ ${entry.amountPaid.toStringAsFixed(2)}',
            ),
            _DetailRow(
              icon: Icons.confirmation_number,
              label: 'Código',
              value: entry.confirmationCode ?? '-',
            ),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Fecha',
              value: DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt),
            ),
            if (entry.receiptUrl case final url? when url.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openReceipt(context, url),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Ver recibo'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (busy)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: locked
                          ? null
                          : () => _confirm(context, approve: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: locked
                          ? null
                          : () => _confirm(context, approve: true),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.muted),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
