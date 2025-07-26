import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/add_transaction_bottom_sheet.dart';

class TransactionDetailsDialog {
  static void show({
    required BuildContext context,
    required Transaction transaction,
    required NumberFormat currencyFormat,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionDetailsSheet(
        transaction: transaction,
        currencyFormat: currencyFormat,
      ),
    );
  }
}

class _TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;
  final NumberFormat currencyFormat;

  const _TransactionDetailsSheet({
    required this.transaction,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = _isIncomeTransaction(transaction);
    final color = isIncome ? Colors.green : Colors.red;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, color, isIncome),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTransactionInfo(context),
                  const SizedBox(height: 24),
                  _buildEditHistory(context),
                  const SizedBox(height: 24),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color color, bool isIncome) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.trending_up : Icons.trending_down,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (transaction.transactionNumber != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#${transaction.transactionNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            transaction.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${isIncome ? '+' : '-'} ${currencyFormat.format(transaction.amount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Category', transaction.category, Icons.category),
            _buildDetailRow(
              'Date', 
              DateFormat('EEEE, MMM dd, yyyy').format(transaction.date),
              Icons.calendar_today,
            ),
            _buildDetailRow('Type', transaction.type.toUpperCase(), Icons.swap_horiz),
            if (transaction.isRecurring) ...[
              _buildDetailRow(
                'Frequency', 
                transaction.recurringFrequency ?? 'N/A',
                Icons.repeat,
              ),
              if (transaction.nextDueDate != null)
                _buildDetailRow(
                  'Next Due', 
                  DateFormat('MMM dd, yyyy').format(transaction.nextDueDate!),
                  Icons.schedule,
                ),
            ],
            if (transaction.virtualBankId != null)
              _buildDetailRow('Virtual Bank', 'Yes', Icons.account_balance),
            if (transaction.receiptPath != null)
              _buildDetailRow('Receipt', 'Attached', Icons.receipt),
            _buildDetailRow(
              'Created', 
              DateFormat('MMM dd, yyyy HH:mm').format(transaction.createdAt),
              Icons.access_time,
            ),
            if (transaction.updatedAt != transaction.createdAt)
              _buildDetailRow(
                'Last Updated', 
                DateFormat('MMM dd, yyyy HH:mm').format(transaction.updatedAt),
                Icons.update,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditHistory(BuildContext context) {
    if (transaction.editHistory == null || transaction.editHistory!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: AppTheme.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Anti-Tampering Audit Trail',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...transaction.editHistory!.map((edit) => _buildAuditEntry(context, edit)),
            if (transaction.originalTransactionId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      color: Colors.orange[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This transaction was created from editing Transaction #${transaction.originalTransactionId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditEntry(BuildContext context, Map<String, dynamic> edit) {
    final action = edit['action'] ?? 'unknown';
    final timestamp = edit['timestamp'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(edit['timestamp'])
        : DateTime.now();
    final changes = edit['changes'] as Map<String, dynamic>?;
    
    IconData icon;
    Color color;
    String actionText;
    
    switch (action) {
      case 'created_from_edit':
        icon = Icons.add_circle;
        color = Colors.green;
        actionText = 'Created from Edit';
        break;
      case 'archived_for_edit':
        icon = Icons.archive;
        color = Colors.orange;
        actionText = 'Archived (Original)';
        break;
      case 'minor_edit':
        icon = Icons.edit;
        color = Colors.blue;
        actionText = 'Minor Edit';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        actionText = 'Unknown Action';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                actionText,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (changes != null && changes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...changes.entries.map((change) => _buildChangeDetail(context, change.key, change.value)),
          ],
          if (edit['original_transaction_id'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Linked to Transaction #${edit['original_transaction_id']}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeDetail(BuildContext context, String field, dynamic changeData) {
    if (changeData is Map<String, dynamic>) {
      final from = changeData['from'];
      final to = changeData['to'];
      
      return Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 4),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            children: [
              TextSpan(
                text: '${_formatFieldName(field)}: ',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: _formatFieldValue(field, from),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.red,
                ),
              ),
              const TextSpan(text: ' → '),
              TextSpan(
                text: _formatFieldValue(field, to),
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Text(
        '${_formatFieldName(field)}: $changeData',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  String _formatFieldName(String field) {
    switch (field) {
      case 'amount':
        return 'Amount';
      case 'type':
        return 'Type';
      case 'category':
        return 'Category';
      case 'description':
        return 'Description';
      case 'date':
        return 'Date';
      case 'virtual_bank_id':
        return 'Payment Source';
      default:
        return field.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatFieldValue(String field, dynamic value) {
    if (value == null) return 'None';
    
    switch (field) {
      case 'amount':
        return '₹${value.toString()}';
      case 'type':
        return value.toString().toUpperCase();
      case 'date':
        try {
          final date = DateTime.parse(value.toString());
          return DateFormat('MMM dd, yyyy').format(date);
        } catch (e) {
          return value.toString();
        }
      case 'virtual_bank_id':
        return value.toString() == 'null' ? 'Main Balance' : 'Virtual Bank';
      default:
        return value.toString();
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppTheme.gradientButton(
                onPressed: () {
                  Navigator.pop(context);
                  _editTransaction(context);
                },
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.edit, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showRevertConfirmation(context),
                icon: const Icon(Icons.undo),
                label: const Text('Revert'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  void _editTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionBottomSheet(
        editTransaction: transaction,
      ),
    );
  }

  void _showRevertConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Revert Transaction'),
          content: Text(
            'Are you sure you want to revert this transaction?\n\n'
            'This will remove "${transaction.description}" '
            '(${currencyFormat.format(transaction.amount)}) from your records.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close details sheet
                _revertTransaction(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Revert'),
            ),
          ],
        );
      },
    );
  }

  void _revertTransaction(BuildContext context) async {
    try {
      await context.read<FinanceProvider>().deleteTransaction(transaction.id!);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction reverted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reverting transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isIncomeTransaction(Transaction transaction) {
    return transaction.type == 'income' || 
           (transaction.type == 'recurring' && _isIncomeCategory(transaction.category));
  }

  bool _isIncomeCategory(String category) {
    return FinanceProvider.incomeCategories.contains(category);
  }
}