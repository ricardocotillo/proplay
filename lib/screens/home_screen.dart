import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proplay/utils/auth_helper.dart';
import 'package:proplay/widgets/app_drawer.dart';
import 'package:proplay/widgets/wallet_indicator.dart';
import 'package:proplay/bloc/group/group_bloc.dart';
import 'package:proplay/bloc/group/group_event.dart';
import 'package:proplay/bloc/group/group_state.dart';
import 'package:proplay/services/storage_service.dart';
import 'package:proplay/services/credit_history_service.dart';
import 'package:proplay/screens/credit_history_screen.dart';
import 'package:proplay/services/user_service.dart';
import 'package:proplay/bloc/auth/auth_bloc.dart';
import 'package:proplay/bloc/auth/auth_event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _checkSportsSelection();
  }

  void _checkSportsSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.currentUser;
      if (user != null && user.sports.isEmpty) {
        _showSportsSelectionDialog();
      }
    });
  }

  void _loadGroups() {
    final user = context.currentUser;
    if (user != null) {
      context.read<GroupBloc>().add(GroupLoadUserGroups(user.uid));
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        leading: IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          onPressed: () {
            // TODO: Handle notification tap
          },
          icon: const Icon(Icons.notifications_none),
        ),
        actions: [
          WalletIndicator(onTap: _showAddCreditsDialog),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: _openDrawer,
              child: user?.profileImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: user!.profileImageUrl!,
                      imageBuilder: (context, imageProvider) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      placeholder: (context, url) => const CircleAvatar(
                        radius: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const CircleAvatar(
                        radius: 20,
                        child: Icon(Icons.person),
                      ),
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        user != null
                            ? '${user.firstName[0]}${user.lastName[0]}'
                                  .toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      endDrawer: const AppDrawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, ${user?.firstName ?? ''}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Juega como un pro',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocConsumer<GroupBloc, GroupState>(
              listener: (context, state) {
                if (state is GroupJoinSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadGroups();
                } else if (state is GroupDeleteSuccess) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                  _loadGroups();
                }
              },
              builder: (context, state) {
                if (state is GroupLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is GroupLoaded) {
                  if (state.groups.isEmpty) {
                    return _buildEmptyState(context);
                  }
                  return _buildGroupsList(state.groups);
                }

                if (state is GroupError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadGroups,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                return _buildEmptyState(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              const TextSpan(text: 'No tienes un grupo aun? '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () {
                    context.push('/create-group').then((result) {
                      if (result != null) {
                        _loadGroups();
                      }
                    });
                  },
                  child: Text(
                    'crea',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ' o '),
              WidgetSpan(
                child: GestureDetector(
                  onTap: () => _showJoinGroupDialog(),
                  child: Text(
                    'unete a uno',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsList(List groups) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.push('/sessions');
                  },
                  icon: const Icon(Icons.sports_soccer),
                  label: const Text('Pichangas'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/create-group').then((result) {
                          if (result != null) {
                            _loadGroups();
                          }
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Crear Grupo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showJoinGroupDialog(),
                      icon: const Icon(Icons.group_add),
                      label: const Text('Unirse a Grupo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  visualDensity: VisualDensity.compact,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    group.sports.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      group.code,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  onTap: () {
                    context.push('/group/${group.id}');
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a Grupo'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Código del Grupo',
            border: OutlineInputBorder(),
            hintText: 'Ingresa el código de 6 caracteres',
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim().toUpperCase();
              if (code.length == 6) {
                final user = this.context.currentUser;
                if (user != null) {
                  this.context.read<GroupBloc>().add(
                    GroupJoinRequested(code: code, userId: user.uid),
                  );
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  void _showAddCreditsDialog() {
    showDialog(
      context: context,
      builder: (context) => const _AddCreditsDialog(),
    );
  }

  void _showSportsSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SportsSelectionDialog(
        onSportsSelected: (selectedSports) async {
          final user = this.context.currentUser;
          if (user != null && selectedSports.isNotEmpty) {
            try {
              // Update sports in Firestore
              final userService = UserService();
              await userService.updateUser(user.uid, {
                'sports': selectedSports,
              });

              // Refresh user data in AuthBloc
              if (mounted) {
                this.context.read<AuthBloc>().add(const AuthRefreshUserRequested());
              }

              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Deportes guardados exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Error al guardar deportes: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }
}

class _AddCreditsDialog extends StatefulWidget {
  const _AddCreditsDialog();

  @override
  State<_AddCreditsDialog> createState() => _AddCreditsDialogState();
}

class _AddCreditsDialogState extends State<_AddCreditsDialog> {
  int _currentStep = 0; // 0: confirmation, 1: package selection, 2: upload
  File? _selectedImage;
  bool _isUploading = false;
  int? _selectedCoins;
  int? _selectedPrice;
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final CreditHistoryService _creditHistoryService = CreditHistoryService();

  static const String _phoneNumber = '970001095';

  final List<Map<String, int>> _packages = [
    {'coins': 15, 'price': 16},
    {'coins': 25, 'price': 27},
    {'coins': 50, 'price': 52},
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadReceipt() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una imagen'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = context.currentUser;
    if (user == null) return;

    if (_selectedCoins == null || _selectedPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se seleccionó un paquete'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Read file bytes (more reliable for temp files from image picker)
      final bytes = await _selectedImage!.readAsBytes();

      // Upload receipt to Firebase Storage
      final downloadUrl = await _storageService.uploadPaymentReceipt(
        user.uid,
        bytes,
      );

      // Create credit history entry in Firestore
      await _creditHistoryService.createCreditHistory(
        userId: user.uid,
        creditAmount: _selectedCoins!,
        phoneNumber: _phoneNumber,
        amountPaid: _selectedPrice!.toDouble(),
        receiptUrl: downloadUrl,
      );

      if (mounted) {
        Navigator.pop(context);

        // Navigate to credit history screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreditHistoryScreen()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Comprobante enviado exitosamente. Tu crédito será agregado pronto.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print(e);
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir comprobante: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 0: Confirmation
    if (_currentStep == 0) {
      return AlertDialog(
        title: const Text('Agregar Créditos'),
        content: const Text('¿Deseas agregar más créditos a tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStep = 1;
              });
            },
            child: const Text('Agregar'),
          ),
        ],
      );
    }

    // Step 1: Package Selection
    if (_currentStep == 1) {
      return AlertDialog(
        title: const Text('Selecciona un Paquete'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _packages.map((package) {
              final coins = package['coins']!;
              final price = package['price']!;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCoins = coins;
                      _selectedPrice = price;
                      _currentStep = 2;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$coins Créditos',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S/ $price.00',
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
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      );
    }

    // Step 2: Upload Receipt
    return AlertDialog(
      title: const Text('Subir Comprobante'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedCoins Créditos - S/ $_selectedPrice.00',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Envía tu pago por Yape o Plin al número:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
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
                    Icons.phone,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _phoneNumber,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Luego sube una captura de pantalla del comprobante:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            if (_selectedImage != null) ...[
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 200,
                      maxWidth: 300,
                    ),
                    child: Image.file(_selectedImage!, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickImage,
                icon: const Icon(Icons.image),
                label: Text(
                  _selectedImage == null
                      ? 'Seleccionar Imagen'
                      : 'Cambiar Imagen',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading
              ? null
              : () {
                  setState(() {
                    _currentStep = 1;
                    _selectedImage = null;
                  });
                },
          child: const Text('Atrás'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _uploadReceipt,
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}

class _SportsSelectionDialog extends StatefulWidget {
  final Function(List<String>) onSportsSelected;

  const _SportsSelectionDialog({required this.onSportsSelected});

  @override
  State<_SportsSelectionDialog> createState() => _SportsSelectionDialogState();
}

class _SportsSelectionDialogState extends State<_SportsSelectionDialog> {
  final List<Map<String, dynamic>> _availableSports = [
    {'name': 'Fútbol', 'icon': Icons.sports_soccer},
    {'name': 'Baloncesto', 'icon': Icons.sports_basketball},
    {'name': 'Voleibol', 'icon': Icons.sports_volleyball},
    {'name': 'Tenis', 'icon': Icons.sports_tennis},
    {'name': 'Natación', 'icon': Icons.pool},
    {'name': 'Running', 'icon': Icons.directions_run},
    {'name': 'Ciclismo', 'icon': Icons.directions_bike},
    {'name': 'Gimnasio', 'icon': Icons.fitness_center},
    {'name': 'Pádel', 'icon': Icons.sports_tennis},
    {'name': 'Béisbol', 'icon': Icons.sports_baseball},
  ];

  final Set<String> _selectedSports = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Selecciona tus Deportes',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elige los deportes que te interesan:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._availableSports.map((sport) {
              final sportName = sport['name'] as String;
              final sportIcon = sport['icon'] as IconData;
              final isSelected = _selectedSports.contains(sportName);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedSports.add(sportName);
                    } else {
                      _selectedSports.remove(sportName);
                    }
                  });
                },
                title: Row(
                  children: [
                    Icon(
                      sportIcon,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(sportName),
                  ],
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _selectedSports.isEmpty
              ? null
              : () {
                  widget.onSportsSelected(_selectedSports.toList());
                  Navigator.pop(context);
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
