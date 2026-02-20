import 'package:proplay/models/payment_result_model.dart';

/// Abstract payment service interface.
/// Implement this for each payment gateway (Stripe, MercadoPago, PayPal, etc.).
abstract class PaymentService {
  Future<PaymentResult> processPayment({
    required CreditPackage package,
    required String userId,
    required CardDetails cardDetails,
  });
}

/// Stub implementation for testing the full flow before choosing a gateway provider.
/// Always returns a successful payment result.
class StubPaymentService implements PaymentService {
  @override
  Future<PaymentResult> processPayment({
    required CreditPackage package,
    required String userId,
    required CardDetails cardDetails,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    return PaymentResult(
      success: true,
      transactionId: 'stub_${DateTime.now().millisecondsSinceEpoch}',
      paymentMethod: 'card',
      paymentGateway: 'stub',
    );
  }
}
