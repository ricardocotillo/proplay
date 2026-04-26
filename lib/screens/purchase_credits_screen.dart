import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/models/payment_result_model.dart';
import 'package:proplay/services/payment_service.dart';
import 'package:proplay/bloc/credit/credit_bloc.dart';
import 'package:proplay/bloc/credit/credit_event.dart';
import 'package:proplay/bloc/credit/credit_state.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/models/mp_preference_model.dart';
import 'package:proplay/mp.dart' as mp;
import 'package:proplay/utils/launch.dart';
import 'package:proplay/widgets/responsive_layout.dart';

class PurchaseCreditsScreen extends StatefulWidget {
  const PurchaseCreditsScreen({super.key});

  @override
  State<PurchaseCreditsScreen> createState() => _PurchaseCreditsScreenState();
}

class _PurchaseCreditsScreenState extends State<PurchaseCreditsScreen> {
  CreditPackage? _selectedPackage;
  bool _isProcessing = false;
  final List<MpPreference> _preferences = mp.preferences
      .map((pref) => MpPreference.fromMap(pref))
      .toList();

  void _selectPackage(CreditPackage package) {
    MpPreference? pref;
    for (final p in _preferences) {
      final title = p.items.isNotEmpty ? (p.items.first.title ?? '') : '';
      final normalized = title.trim().toLowerCase();
      if (normalized.startsWith('${package.credits} ')) {
        pref = p;
        break;
      }
    }

    String? url = pref?.initPoint;
    if (url != null) {
      launchURL(context, url);
    }
    // setState(() {
    //   _selectedPackage = package;
    // });
  }

  void _goBackToPackages() {
    setState(() {
      _selectedPackage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreditBloc, CreditState>(
      listener: (context, state) {
        if (state is CreditPurchaseSuccess) {
          context.read<AuthBloc>().add(const AuthRefreshUserRequested());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${state.creditsAdded} créditos agregados. Nuevo saldo: ${state.newBalance}',
              ),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        } else if (state is CreditPurchaseFailure) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectedPackage == null ? 'Comprar Créditos' : 'Datos de Pago',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedPackage != null && !_isProcessing) {
                _goBackToPackages();
              } else if (!_isProcessing) {
                context.pop();
              }
            },
          ),
        ),
        body: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Procesando pago...'),
                  ],
                ),
              )
            : _selectedPackage == null
            ? _PackageSelectionView(onSelect: _selectPackage)
            : _PaymentFormView(
                package: _selectedPackage!,
                onProcessing: (processing) {
                  setState(() {
                    _isProcessing = processing;
                  });
                },
              ),
      ),
    );
  }
}

// --- Package Selection ---

class _PackageSelectionView extends StatelessWidget {
  final void Function(CreditPackage) onSelect;

  const _PackageSelectionView({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ResponsiveConstrainedBox(
      maxWidth: 600,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Selecciona un paquete',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige la cantidad de créditos que deseas comprar.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ...CreditPackage.packages.map(
            (package) =>
                _PackageCard(package: package, onTap: () => onSelect(package)),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final CreditPackage package;
  final VoidCallback onTap;

  const _PackageCard({required this.package, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${package.credits} pro coins',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S/ ${package.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Payment Form ---

class _PaymentFormView extends StatefulWidget {
  final CreditPackage package;
  final void Function(bool) onProcessing;

  const _PaymentFormView({required this.package, required this.onProcessing});

  @override
  State<_PaymentFormView> createState() => _PaymentFormViewState();
}

class _PaymentFormViewState extends State<_PaymentFormView> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  String _country = 'Perú';

  static const _countries = [
    'Perú',
    'Argentina',
    'Bolivia',
    'Brasil',
    'Chile',
    'Colombia',
    'Ecuador',
    'Paraguay',
    'Uruguay',
    'Venezuela',
    'México',
    'Estados Unidos',
    'España',
    'Otro',
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final user = context.currentUser;
    if (user == null) return;

    widget.onProcessing(true);

    final cardDetails = CardDetails(
      cardNumber: _cardNumberController.text.replaceAll(' ', ''),
      cardHolderName: _cardHolderController.text.trim(),
      expiryDate: _expiryController.text.trim(),
      cvv: _cvvController.text.trim(),
      billingAddress: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _postalCodeController.text.trim(),
      country: _country,
    );

    try {
      final paymentService = context.read<PaymentService>();
      final result = await paymentService.processPayment(
        package: widget.package,
        userId: user.uid,
        cardDetails: cardDetails,
      );

      if (!mounted) return;

      if (result.success) {
        context.read<CreditBloc>().add(
          CreditPurchaseRequested(
            userId: user.uid,
            package: widget.package,
            paymentResult: result,
          ),
        );
      } else {
        widget.onProcessing(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Error en el pago'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        widget.onProcessing(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar el pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa el número de tarjeta';
    }
    final digits = value.replaceAll(' ', '');
    if (digits.length < 13 || digits.length > 19) {
      return 'Número de tarjeta inválido';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa la fecha de expiración';
    }
    final regex = RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$');
    if (!regex.hasMatch(value)) {
      return 'Formato inválido (MM/AA)';
    }
    return null;
  }

  String? _validateCvv(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa el CVV';
    }
    if (value.length < 3 || value.length > 4) {
      return 'CVV inválido';
    }
    return null;
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveConstrainedBox(
      maxWidth: 600,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Package summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.package.credits} Créditos — S/ ${widget.package.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card information section
            Text(
              'Información de la tarjeta',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardNumberController,
              decoration: const InputDecoration(
                labelText: 'Número de tarjeta',
                hintText: '0000 0000 0000 0000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(19),
                _CardNumberFormatter(),
              ],
              validator: _validateCardNumber,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cardHolderController,
              decoration: const InputDecoration(
                labelText: 'Nombre del titular',
                hintText: 'Como aparece en la tarjeta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              validator: _validateRequired,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    decoration: const InputDecoration(
                      labelText: 'Expiración',
                      hintText: 'MM/AA',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                      _ExpiryDateFormatter(),
                    ],
                    validator: _validateExpiry,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '***',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: _validateCvv,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Billing address section
            Text(
              'Dirección de facturación',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                hintText: 'Calle, número, departamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
              validator: _validateRequired,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateRequired,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'Región / Estado',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateRequired,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Código postal',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validateRequired,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _country,
                    decoration: const InputDecoration(
                      labelText: 'País',
                      border: OutlineInputBorder(),
                    ),
                    items: _countries
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _country = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitPayment,
                icon: const Icon(Icons.lock),
                label: Text(
                  'Pagar S/ ${widget.package.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Pago seguro y encriptado',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// --- Input Formatters ---

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
