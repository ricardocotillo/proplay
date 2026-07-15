import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:proplay/models/credit_history_model.dart';
import 'package:proplay/utils/auth_helper.dart';

class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({super.key});

  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<CreditHistoryModel> _creditHistory = [];
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
    final user = context.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creditHistory')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _creditHistory.addAll(
          snapshot.docs.map((doc) => CreditHistoryModel.fromDocument(doc)),
        );
        _hasMore = snapshot.docs.length == _pageSize;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar historial: $e'),
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

    final user = context.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('creditHistory')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _creditHistory.addAll(
          snapshot.docs.map((doc) => CreditHistoryModel.fromDocument(doc)),
        );
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

  Future<void> _refresh() async {
    setState(() {
      _creditHistory.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    await _loadInitialData();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
      case 'completed':
        return Colors.green;
      case 'rejected':
      case 'failed':
        return Colors.red;
      case 'refunded':
        return Colors.blue;
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
      case 'completed':
        return 'Completado';
      case 'rejected':
        return 'Rechazado';
      case 'failed':
        return 'Fallido';
      case 'refunded':
        return 'Reembolsado';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Créditos')),
      body: _creditHistory.isEmpty && !_isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay historial de créditos',
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
                itemCount: _creditHistory.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _creditHistory.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final history = _creditHistory[index];
                  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: history.direction == 'debit'
                              ? Colors.red.withValues(alpha: 0.1)
                              : Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          history.entryType == 'spend'
                              ? Icons.sports_soccer
                              : history.entryType == 'refund'
                              ? Icons.replay
                              : history.entryType == 'adjustment'
                              ? Icons.settings
                              : Icons.account_balance_wallet,
                          color: history.direction == 'debit'
                              ? Colors.red
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        history.entryType == 'spend'
                            ? history.sessionTitle ?? 'Pichanga'
                            : history.entryType == 'refund'
                            ? 'Reembolso: ${history.sessionTitle ?? ""}'
                            : history.entryType == 'adjustment'
                            ? 'Ajuste: ${history.notes ?? ""}'
                            : '${history.creditAmount} Créditos',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (history.entryType == 'spend' ||
                              history.entryType == 'refund' ||
                              history.entryType == 'adjustment')
                            Text(
                              '${history.creditAmount} créditos',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Text(
                            dateFormat.format(history.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    history.status,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getStatusColor(history.status),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getStatusText(history.status),
                                  style: TextStyle(
                                    color: _getStatusColor(history.status),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (history.balanceAfter != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Saldo: ${history.balanceAfter!.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: history.amountPaid > 0
                          ? Text(
                              'S/ ${history.amountPaid.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Text(
                              '${history.direction == 'debit' ? '-' : '+'}${history.creditAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: history.direction == 'debit'
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
