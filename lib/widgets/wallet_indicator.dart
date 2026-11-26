import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:proplay/bloc/pending_credits/pending_credits_cubit.dart';
import 'package:proplay/models/user_model.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/theme/app_colors.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';

/// Balance pill (S/, 1 credit = S/ 1) with a refresh button and, while a
/// Yape top-up waits for approval, the pending amount.
class WalletIndicator extends StatelessWidget {
  final VoidCallback onTap;

  const WalletIndicator({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Only this widget watches user state, so only this rebuilds on refresh
    final user = context.watchUser;
    if (user == null) return const SizedBox.shrink();

    return BlocProvider(
      key: ValueKey(user.uid),
      create: (context) =>
          PendingCreditsCubit(context.read<CreditHistoryService>(), user.uid),
      child: BlocConsumer<PendingCreditsCubit, double>(
        // An approval moves credits from pending to the balance.
        listenWhen: (previous, current) => current < previous,
        listener: (context, _) =>
            context.read<AuthBloc>().add(const AuthRefreshUserRequested()),
        builder: (context, pending) => _pill(context, user, pending),
      ),
    );
  }

  Widget _pill(BuildContext context, UserModel user, double pending) {
    const textStyle = TextStyle(
      color: AppColors.selectedText,
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      decoration: BoxDecoration(
        color: AppColors.selectedTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 18,
                    color: AppColors.selectedText,
                  ),
                  const SizedBox(width: 6),
                  Text('S/ ${user.credits}', style: textStyle),
                  if (pending > 0) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          'Recarga de S/ ${UserModel.formatCredits(pending)} en revisión',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '+${UserModel.formatCredits(pending)}',
                            style: textStyle.copyWith(color: AppColors.warning),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              // Refresh user data from Firestore to get latest credits
              context.read<AuthBloc>().add(const AuthRefreshUserRequested());
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(
                Icons.refresh,
                size: 18,
                color: AppColors.selectedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
