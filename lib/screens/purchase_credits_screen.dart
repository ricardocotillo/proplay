import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/models/payment_result_model.dart';
import 'package:proplay/bloc/credit/credit_bloc.dart';
import 'package:proplay/bloc/credit/credit_event.dart';
import 'package:proplay/bloc/credit/credit_state.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';
import 'package:proplay/widgets/responsive_layout.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/services/yape_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PurchaseCreditsScreen extends StatefulWidget {
  const PurchaseCreditsScreen({super.key});

  @override
  State<PurchaseCreditsScreen> createState() => _PurchaseCreditsScreenState();
}

class _PurchaseCreditsScreenState extends State<PurchaseCreditsScreen> {
  CreditPackage? _selectedPackage;
  bool _isProcessing = false;

  void _selectPackage(CreditPackage package) {
    setState(() {
      _selectedPackage = package;
    });
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
            : _YapePaymentFlow(
                package: _selectedPackage!,
                onCancel: _goBackToPackages,
              ),
      ),
    );
  }
}

// --- Yape Payment Flow ---

enum _YapeStep { send, confirm }

class _YapePaymentFlow extends StatefulWidget {
  final CreditPackage package;
  final VoidCallback onCancel;

  const _YapePaymentFlow({required this.package, required this.onCancel});

  @override
  State<_YapePaymentFlow> createState() => _YapePaymentFlowState();
}

class _YapePaymentFlowState extends State<_YapePaymentFlow> {
  _YapeStep _currentStep = _YapeStep.send;
  YapeConfig? _yapeConfig;
  bool _isLoading = true;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadYapeConfig();
  }

  Future<void> _loadYapeConfig() async {
    final config = await context.read<YapeService>().getYapeConfig();
    if (mounted) {
      setState(() {
        _yapeConfig = config;
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    setState(() {
      _currentStep = _YapeStep.confirm;
    });
  }

  void _confirmPayment() {
    final code = _codeController.text;
    if (code.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa los 3 dígitos del código')),
      );
      return;
    }

    final user = context.currentUser;
    if (user != null) {
      context.read<CreditBloc>().add(
        CreditPurchaseRequested(
          userId: user.uid,
          package: widget.package,
          paymentResult: PaymentResult(
            success: true,
            transactionId: 'yape_$code',
            paymentMethod: 'yape',
            paymentGateway: 'yape',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_yapeConfig == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No se pudo cargar la información de Yape'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onCancel,
              child: const Text('Volver'),
            ),
          ],
        ),
      );
    }

    return ResponsiveConstrainedBox(
      maxWidth: 600,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _StepIndicator(currentStep: _currentStep),
                  const SizedBox(height: 32),
                  if (_currentStep == _YapeStep.send)
                    _YapeSendStep(config: _yapeConfig!, package: widget.package)
                  else
                    _YapeConfirmStep(controller: _codeController),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _currentStep == _YapeStep.send
                    ? _nextStep
                    : _confirmPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1B1D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _currentStep == _YapeStep.send
                      ? 'Ya copié el número'
                      : 'Confirmar Pago',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final _YapeStep currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFBA1B1D);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCircle('1', true),
        Container(
          width: 40,
          height: 2,
          color: currentStep == _YapeStep.confirm
              ? primaryColor
              : Colors.grey[300],
        ),
        _buildCircle('2', currentStep == _YapeStep.confirm),
      ],
    );
  }

  Widget _buildCircle(String text, bool active) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFBA1B1D) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _YapeSendStep extends StatelessWidget {
  final YapeConfig config;
  final CreditPackage package;

  const _YapeSendStep({required this.config, required this.package});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Envía el Yape',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Copia el número y realiza el pago en tu app.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFBA1B1D), Color(0xFF8B1416)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: config.qr,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 200,
                    color: Colors.white,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                config.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      config.phone,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFBA1B1D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: Color(0xFFBA1B1D),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: config.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Número copiado')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monto a pagar:',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              Text(
                'S/ ${package.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _YapeConfirmStep extends StatelessWidget {
  final TextEditingController controller;

  const _YapeConfirmStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Confirma el Pago',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa los últimos 3 dígitos del código de operación.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              Text(
                'CÓDIGO DE OPERACIÓN',
                style: TextStyle(
                  color: const Color(0xFFBA1B1D).withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  maxLength: 3,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '0 0 0',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
        ),
      ],
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
