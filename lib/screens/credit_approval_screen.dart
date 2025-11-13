import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:proplay/models/credit_history_model.dart';
import 'package:proplay/models/user_model.dart';

class CreditApprovalScreen extends StatefulWidget {
  const CreditApprovalScreen({super.key});

  @override
  State<CreditApprovalScreen> createState() => _CreditApprovalScreenState();
}

class _CreditApprovalScreenState extends State<CreditApprovalScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<_CreditApprovalItem> _approvalItems = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creditHistory')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        await _loadUserDataForDocs(snapshot.docs);
        _hasMore = snapshot.docs.length == _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar solicitudes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_lastDocument == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creditHistory')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        await _loadUserDataForDocs(snapshot.docs);
        _hasMore = snapshot.docs.length == _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar más datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserDataForDocs(List<QueryDocumentSnapshot> docs) async {
    for (var doc in docs) {
      final creditHistory = CreditHistoryModel.fromDocument(doc);

      // Fetch user data
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(creditHistory.userId)
            .get();

        if (userDoc.exists) {
          final user = UserModel.fromDocument(userDoc);
          _approvalItems.add(
            _CreditApprovalItem(creditHistory: creditHistory, user: user),
          );
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _approvalItems.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialData();
  }

  Future<void> _openReceipt(String? receiptUrl) async {
    if (receiptUrl == null || receiptUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay recibo disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final uri = Uri.parse(receiptUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el recibo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showApprovalDialog(_CreditApprovalItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aprobar Créditos'),
        content: Text(
          '¿Confirmas que quieres aprobar ${item.creditHistory.creditAmount} créditos para ${item.user.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _approveCredit(item);
    }
  }

  Future<void> _approveCredit(_CreditApprovalItem item) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Aprobando créditos...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }

      // IMPORTANT: Get userId from creditHistory entry to ensure correct user is updated
      final targetUserId = item.creditHistory.userId;
      final creditsToAdd = item.creditHistory.creditAmount;

      // Verify user exists before making any changes
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .get();

      if (!userDoc.exists) {
        throw Exception('Usuario no encontrado con ID: $targetUserId');
      }

      // Verify the userId matches what we expect
      if (targetUserId != item.user.uid) {
        throw Exception('Error de verificación: ID de usuario no coincide');
      }

      final currentUser = UserModel.fromDocument(userDoc);
      final currentCredits = currentUser.credits;
      final newCreditAmount = currentCredits + creditsToAdd;

      debugPrint('Approving credits:');
      debugPrint('  User ID: $targetUserId');
      debugPrint('  User Name: ${currentUser.fullName}');
      debugPrint('  Current Credits: $currentCredits');
      debugPrint('  Adding Credits: $creditsToAdd');
      debugPrint('  New Total: $newCreditAmount');

      // Use Firestore transaction to ensure atomic operation
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Update credit history status to 'approved'
        final creditHistoryRef = FirebaseFirestore.instance
            .collection('creditHistory')
            .doc(item.creditHistory.id);
        transaction.update(creditHistoryRef, {'status': 'approved'});

        // Update user's credit amount using the userId from creditHistory
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId);
        transaction.update(userRef, {'credit': newCreditAmount});
      });

      // Remove from local list
      if (mounted) {
        setState(() {
          _approvalItems.remove(item);
        });

        // Hide loading and show success
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Créditos aprobados exitosamente para ${currentUser.fullName} (${currentCredits} → ${newCreditAmount})',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar créditos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pendiente';
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aprobar Créditos')),
      body: _approvalItems.isEmpty && !_isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay solicitudes pendientes',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _approvalItems.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _approvalItems.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final item = _approvalItems[index];
                  final creditHistory = item.creditHistory;
                  final user = item.user;
                  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User name
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.2),
                                child: Text(
                                  '${user.firstName[0]}${user.lastName[0]}'
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      user.email,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          // Credit details
                          _DetailRow(
                            icon: Icons.account_balance_wallet,
                            label: 'Créditos',
                            value: '${creditHistory.creditAmount}',
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.payments,
                            label: 'Monto Pagado',
                            value:
                                'S/ ${creditHistory.amountPaid.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.phone,
                            label: 'Número',
                            value: creditHistory.phoneNumber,
                          ),
                          const SizedBox(height: 8),
                          _DetailRow(
                            icon: Icons.calendar_today,
                            label: 'Fecha',
                            value: dateFormat.format(creditHistory.createdAt),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Estado:',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    creditHistory.status,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      creditHistory.status,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getStatusText(creditHistory.status),
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      creditHistory.status,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Open receipt button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openReceipt(creditHistory.receiptUrl),
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Ver Recibo'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Approve button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showApprovalDialog(item),
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Aprobar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _CreditApprovalItem {
  final CreditHistoryModel creditHistory;
  final UserModel user;

  _CreditApprovalItem({required this.creditHistory, required this.user});
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
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
