# Plan: Migrate from Manual Credit Approval to Payment Gateway

## Context

The current credit system requires users to pay manually via Yape/Plin, upload a receipt screenshot, and wait for admin approval. This is being replaced with an automated payment gateway flow where users select a credit package, pay via card through a gateway SDK, and credits are added instantly on successful payment. The gateway provider is TBD (Stripe, MercadoPago, PayPal, etc.), so the design uses an abstract interface.

**Key decisions:**
- Fully replace manual Yape/Plin flow (no dual system)
- Auto-approve credits on successful gateway payment (no admin intervention)
- Gateway SDK handles card data (PCI compliance); app receives success/failure confirmation

---

## Step 1: Create Payment Models

**New file: `lib/models/payment_result_model.dart`**

```dart
class CreditPackage {
  final int credits;
  final double price;
  final String currency; // 'PEN'
}

class CardDetails {
  final String cardNumber;
  final String cardHolderName;
  final String expiryDate;  // MM/YY
  final String cvv;
  final String billingAddress;
  final String city;
  final String state;
  final String postalCode;
  final String country;
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? paymentMethod; // 'card', 'wallet', etc.
  final String? errorMessage;
}
```

Define the credit packages here (moved from `_AddCreditsDialog`'s hardcoded list):
- 15 credits / S/ 17
- 25 credits / S/ 28
- 50 credits / S/ 55

---

## Step 2: Create Abstract PaymentService

**New file: `lib/services/payment_service.dart`**

```dart
abstract class PaymentService {
  Future<PaymentResult> processPayment({
    required CreditPackage package,
    required String userId,
    required CardDetails cardDetails,
  });
}
```

Also create a `StubPaymentService` implementation that always returns success - this lets the full flow be tested before choosing a provider. When the provider is chosen (e.g., Stripe), create `StripePaymentService implements PaymentService`.

---

## Step 3: Create CreditBloc (BLoC pattern)

**New files:**
- `lib/bloc/credit/credit_event.dart`
- `lib/bloc/credit/credit_state.dart`
- `lib/bloc/credit/credit_bloc.dart`

**Events:**
- `CreditPurchaseRequested(CreditPackage package, PaymentResult paymentResult)` - after gateway confirms success
- `CreditHistoryLoadRequested(String userId)` - load history

**States:**
- `CreditInitial`
- `CreditPurchaseLoading`
- `CreditPurchaseSuccess(int creditsAdded, String newBalance)`
- `CreditPurchaseFailure(String message)`
- `CreditHistoryLoaded(List<CreditHistoryModel> history)`

**BLoC logic:**
- Injected with `CreditHistoryService` and `UserService`
- On `CreditPurchaseRequested`: calls `CreditHistoryService.completeCreditPurchase()` which atomically creates the history record AND adds credits to the user in a Firestore transaction
- On `CreditHistoryLoadRequested`: fetches paginated history

**Pattern reference:** Follow `lib/bloc/group/group_bloc.dart` structure for service injection and event handling.

---

## Step 4: Update CreditHistoryModel

**File: `lib/models/credit_history_model.dart`**

Add new fields, make old fields nullable for backward compatibility:

```
// Remove (make nullable for old records):
- phoneNumber → String? (was required)
- receiptUrl → stays nullable

// Add:
- transactionId: String?
- paymentMethod: String?    // 'card', 'yape', etc.
- paymentGateway: String?   // 'stripe', 'mercadopago', etc.
- currency: String           // default 'PEN'
```

New statuses: `'completed'` | `'failed'` | `'refunded'` (old records keep `'pending'`/`'approved'`/`'rejected'`)

Update `fromMap()` to handle both old and new document formats.

---

## Step 5: Update CreditHistoryService

**File: `lib/services/credit_history_service.dart`**

Add new method:

```dart
Future<void> completeCreditPurchase({
  required String userId,
  required CreditPackage package,
  required PaymentResult paymentResult,
})
```

This method runs a **Firestore transaction** that:
1. Creates a `creditHistory` document with status `'completed'`, transactionId, gateway info
2. Reads current user credits
3. Adds the purchased credits to the user's balance
4. Writes updated credits to the user document

This is the same atomic pattern previously used in `CreditApprovalScreen._approveCredit()`, moved into the service layer.

---

## Step 6: Create PurchaseCreditsScreen

**New file: `lib/screens/purchase_credits_screen.dart`**

Two-step full screen:

**Step 1 - Package selection:**
- List of `CreditPackage` cards
- On package tap → advance to Step 2 (payment form)

**Step 2 - Payment form** (validated with `GlobalKey<FormState>`):
- Selected package summary at the top
- Card number (16 digits, formatted as XXXX XXXX XXXX XXXX)
- Cardholder name (text)
- Expiry date (MM/YY format)
- CVV (3-4 digits, obscured)
- Billing address (street)
- City
- State/Region
- Postal code
- Country (dropdown, default Peru)
- "Pagar S/ XX.00" button

**On submit:**
1. Validate form
2. Build `CardDetails` from form fields
3. Call `PaymentService.processPayment()` with card details
4. On success → dispatch `CreditPurchaseRequested` to `CreditBloc`
5. On failure → show error snackbar
6. **BlocListener** for `CreditPurchaseSuccess` → show success snackbar, pop back to home
7. **BlocListener** for `CreditPurchaseFailure` → show error snackbar

The app collects card details and passes them to the `PaymentService`, which forwards them to the chosen gateway provider for processing.

---

## Step 7: Wire Everything in main.dart

**File: `lib/main.dart`**

1. Add `PaymentService` (StubPaymentService initially) to `MultiRepositoryProvider`
2. Add `CreditHistoryService` to `MultiRepositoryProvider`
3. Add `CreditBloc` to `MultiBlocProvider` (inject CreditHistoryService and UserService)
4. Add GoRouter route: `'/purchase-credits'` → `PurchaseCreditsScreen`

---

## Step 8: Update HomeScreen

**File: `lib/screens/home_screen.dart`**

- Replace `_showAddCreditsDialog()` body with: `context.push('/purchase-credits')`
- Delete the entire `_AddCreditsDialog` class (~370 lines)
- Remove unused imports: `image_picker`, `storage_service`, `credit_history_service`, `credit_history_screen`

---

## Step 9: Update AppDrawer

**File: `lib/widgets/app_drawer.dart`**

- Remove the "Aprobar Creditos" menu item for superusers
- Remove the `credit_approval_screen.dart` import
- Keep the `superUser` field on UserModel for potential future admin features

---

## Step 10: Update CreditHistoryScreen

**File: `lib/screens/credit_history_screen.dart`**

- Update status display to handle both old statuses (`pending`, `approved`, `rejected`) and new (`completed`, `failed`, `refunded`)
- Add display for `paymentMethod` and `transactionId` when available

---

## Step 11: Cleanup

- **Delete:** `lib/screens/credit_approval_screen.dart`
- **Remove** `uploadPaymentReceipt()` from `lib/services/storage_service.dart`
- **Remove** old `createCreditHistory()` from service if no longer referenced
- Clean up any dead imports

---

## Firestore Schema Change

**Before:**
```
creditHistory/{docId}:
  userId, creditAmount, phoneNumber, amountPaid,
  createdAt, status (pending|approved|rejected), receiptUrl?
```

**After:**
```
creditHistory/{docId}:
  userId, creditAmount, amountPaid, currency,
  createdAt, status (completed|failed|refunded),
  transactionId?, paymentMethod?, paymentGateway?,
  phoneNumber? (legacy), receiptUrl? (legacy)
```

No migration needed - `fromMap()` handles both formats.

---

## Implementation Order

1. Create new files first (models, service, bloc, screen) - nothing depends on them yet
2. Update `credit_history_model.dart` - add new fields with backward compatibility
3. Update `credit_history_service.dart` - add `completeCreditPurchase()`
4. Wire providers and route in `main.dart`
5. Update `home_screen.dart` - replace dialog with navigation
6. Update `app_drawer.dart` - remove approval menu item
7. Update `credit_history_screen.dart` - handle new statuses
8. Clean up: delete approval screen, remove dead code

---

## Verification

1. Run `flutter analyze` - no errors
2. Run app with StubPaymentService
3. Tap wallet → navigate to PurchaseCreditsScreen → select package → stub returns success → credits added to Firestore
4. Check CreditHistoryScreen shows the new record with `completed` status
5. Verify old credit history records (if any) still display correctly
6. Confirm approval screen is gone from drawer
7. Confirm no dead imports or unused code warnings

---

## Future: When Gateway Provider is Chosen

1. Add gateway SDK dependency to `pubspec.yaml` (e.g., `flutter_stripe`)
2. Create concrete implementation (e.g., `StripePaymentService implements PaymentService`)
3. Replace `StubPaymentService` with the real implementation in `main.dart`
4. Configure gateway API keys (use environment variables, not hardcoded)
5. **Recommended:** Add a Firebase Cloud Function webhook as a backup to reconcile payments if the client-side Firestore write fails after successful gateway payment
