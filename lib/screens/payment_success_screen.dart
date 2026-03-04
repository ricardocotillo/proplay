import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/bloc/credit/credit_bloc.dart';
import 'package:proplay/bloc/credit/credit_event.dart';
import 'package:proplay/bloc/credit/credit_state.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/models/mp_preference_model.dart';
import 'package:proplay/models/payment_result_model.dart';
import 'package:proplay/mp.dart' as mp;
import 'package:proplay/utils/auth_helper.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String? preferenceId;

  const PaymentSuccessScreen({super.key, this.preferenceId});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;

    final user = context.currentUser;
    if (user == null) {
      debugPrint('PaymentSuccessScreen: user is null (not authenticated)');
      return;
    }

    final preferenceId = widget.preferenceId;
    if (preferenceId == null || preferenceId.isEmpty) {
      debugPrint('PaymentSuccessScreen: preferenceId is null/empty');
      return;
    }

    final prefs = mp.preferences
        .map((e) => MpPreference.fromMap(e))
        .toList(growable: false);
    MpPreference? pref;
    for (final p in prefs) {
      if (p.id == preferenceId) {
        pref = p;
        break;
      }
    }

    if (pref == null) {
      debugPrint(
        'PaymentSuccessScreen: MpPreference not found for id=$preferenceId',
      );
      debugPrint(
        'PaymentSuccessScreen: this usually means the returned preference_id does not match the ids in lib/mp.dart',
      );
      return;
    }

    final title = pref.items.isNotEmpty ? pref.items.first.title ?? '' : '';
    final creditsToAdd = _creditsFromTitle(title);
    if (creditsToAdd == null) {
      debugPrint('PaymentSuccessScreen: unsupported item title="$title"');
      return;
    }

    final package = CreditPackage.packages
        .where((p) => p.credits == creditsToAdd)
        .cast<CreditPackage?>()
        .firstWhere((p) => p != null, orElse: () => null);

    if (package == null) {
      debugPrint(
        'PaymentSuccessScreen: no CreditPackage found for credits=$creditsToAdd',
      );
      return;
    }

    debugPrint(
      'PaymentSuccessScreen: awarding credits=$creditsToAdd for preferenceId=$preferenceId title="$title"',
    );

    context.read<CreditBloc>().add(
      CreditPurchaseRequested(
        userId: user.uid,
        package: package,
        paymentResult: PaymentResult(
          success: true,
          transactionId: preferenceId,
          paymentGateway: 'mercadopago',
          paymentMethod: 'checkout_pro',
        ),
      ),
    );
  }

  int? _creditsFromTitle(String title) {
    final normalized = title.trim().toLowerCase();
    final match = RegExp(r'^(\d+)\s+').firstMatch(normalized);
    final parsed = int.tryParse(match?.group(1) ?? '');
    if (parsed == 15 || parsed == 25 || parsed == 50) {
      return parsed;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocListener<CreditBloc, CreditState>(
      listener: (context, state) {
        if (state is CreditPurchaseSuccess) {
          context.read<AuthBloc>().add(const AuthRefreshUserRequested());
          debugPrint(
            'PaymentSuccessScreen: credits added=${state.creditsAdded}, newBalance=${state.newBalance}',
          );
        } else if (state is CreditPurchaseFailure) {
          debugPrint(
            'PaymentSuccessScreen: failed to add credits: ${state.message}',
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Pago aprobado')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 80, color: colorScheme.primary),
                const SizedBox(height: 16),
                const Text(
                  'Tu pago fue aprobado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes volver a la app. Si no ves los créditos aún, espera unos segundos y revisa nuevamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Ir al inicio'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/purchase-credits'),
                    child: const Text('Volver a comprar créditos'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
