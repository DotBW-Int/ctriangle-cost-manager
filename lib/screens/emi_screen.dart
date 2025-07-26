import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/providers/finance_provider.dart';
import '../core/models/models.dart';
import '../core/widgets/create_emi_dialog.dart';
import '../core/widgets/ct_app_bar.dart';

enum EMISortBy {
  name,
  monthlyAmount,
  remainingAmount,
  progress,
  dueDate,
  interestRate,
}

enum EMIFilter {
  all,
  active,
  completed,
  overdue,
  upcomingSoon,
}

class EMIScreen extends StatefulWidget {
  const EMIScreen({super.key});

  @override
  State<EMIScreen> createState() => _EMIScreenState();
}

class _EMIScreenState extends State<EMIScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  
  EMISortBy _sortBy = EMISortBy.dueDate;
  bool _isAscending = true;
  EMIFilter _filter = EMIFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Process auto-debit EMI payments when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().processEMIAutoDebits();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'C',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              TextSpan(
                text: 'Triangle EMIs',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEMIDialog(),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1e40af), Color(0xFF3b82f6), Color(0xFF60a5fa)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, financeProvider, child) {
          final emis = financeProvider.emis;
          final emiInsights = financeProvider.getEMIInsights();

          // Apply filter
          List<EMI> filteredEmis;
          switch (_filter) {
            case EMIFilter.active:
              filteredEmis = emis.where((emi) => !emi.isCompleted).toList();
              break;
            case EMIFilter.completed:
              filteredEmis = emis.where((emi) => emi.isCompleted).toList();
              break;
            case EMIFilter.overdue:
              filteredEmis = emis.where((emi) => emi.nextDueDate!.isBefore(DateTime.now()) && !emi.isCompleted).toList();
              break;
            case EMIFilter.upcomingSoon:
              filteredEmis = emis.where((emi) => emi.nextDueDate!.isAfter(DateTime.now().subtract(const Duration(days: 1))) && !emi.isCompleted).toList();
              break;
            case EMIFilter.all:
            default:
              filteredEmis = emis;
              break;
          }

          // Apply search
          if (_searchQuery.isNotEmpty) {
            filteredEmis = filteredEmis.where((emi) => emi.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
          }

          // Sort
          filteredEmis.sort((a, b) {
            int comparison;
            switch (_sortBy) {
              case EMISortBy.name:
                comparison = a.name.compareTo(b.name);
                break;
              case EMISortBy.monthlyAmount:
                comparison = a.monthlyEMI.compareTo(b.monthlyEMI);
                break;
              case EMISortBy.remainingAmount:
                comparison = a.remainingAmount.compareTo(b.remainingAmount);
                break;
              case EMISortBy.progress:
                comparison = a.progressPercentage.compareTo(b.progressPercentage);
                break;
              case EMISortBy.dueDate:
                comparison = a.nextDueDate!.compareTo(b.nextDueDate!);
                break;
              case EMISortBy.interestRate:
                comparison = a.interestRate.compareTo(b.interestRate);
                break;
            }
            return _isAscending ? comparison : -comparison;
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEMIOverview(emiInsights),
                const SizedBox(height: 24),
                if (emiInsights['upcomingPayments'].isNotEmpty) ...[
                  _buildUpcomingPayments(emiInsights['upcomingPayments']),
                  const SizedBox(height: 24),
                ],
                _buildFilterAndSearch(),
                const SizedBox(height: 16),
                _buildSortOptions(),
                const SizedBox(height: 24),
                _buildEMIList(filteredEmis),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter & Search',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<EMIFilter>(
                    value: _filter,
                    decoration: const InputDecoration(
                      labelText: 'Filter',
                      prefixIcon: Icon(Icons.filter_list),
                    ),
                    items: EMIFilter.values.map((filter) {
                      return DropdownMenuItem<EMIFilter>(
                        value: filter,
                        child: Text(filter.toString().split('.').last.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _filter = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search EMI',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort Options',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<EMISortBy>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort By',
                      prefixIcon: Icon(Icons.sort),
                    ),
                    items: EMISortBy.values.map((sortBy) {
                      return DropdownMenuItem<EMISortBy>(
                        value: sortBy,
                        child: Text(sortBy.toString().split('.').last.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _sortBy = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Ascending'),
                    value: _isAscending,
                    onChanged: (value) {
                      setState(() {
                        _isAscending = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEMIOverview(Map<String, dynamic> insights) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EMI Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    'Monthly EMI',
                    _currencyFormat.format(insights['totalMonthlyEMI']),
                    Icons.payment,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    'Active EMIs',
                    '${insights['activeEMIs']}',
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewCard(
                    'Remaining',
                    _currencyFormat.format(insights['totalRemainingAmount']),
                    Icons.trending_down,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewCard(
                    'Completed',
                    '${insights['completedEMIs']}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPayments(List<EMI> upcomingPayments) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Payments (Next 7 Days)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...upcomingPayments.map((emi) => _buildUpcomingPaymentItem(emi)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingPaymentItem(EMI emi) {
    final daysLeft = emi.nextDueDate!.difference(DateTime.now()).inDays;
    final isOverdue = daysLeft < 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue 
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue 
              ? Colors.red.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emi.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Due: ${_dateFormat.format(emi.nextDueDate!)}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.orange,
                    fontSize: 12,
                  ),
                ),
                Text(
                  isOverdue 
                      ? '${daysLeft.abs()} days overdue'
                      : daysLeft == 0 
                          ? 'Due today'
                          : '$daysLeft days left',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(emi.monthlyEMI),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () => _showPayEMIDialog(emi),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOverdue ? Colors.red : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'Pay Now',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEMIList(List<EMI> emis) {
    if (emis.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All EMIs',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...emis.map((emi) => _buildEMICard(emi)),
      ],
    );
  }

  Widget _buildEMICard(EMI emi) {
    final progressColor = emi.isCompleted 
        ? Colors.green 
        : emi.progressPercentage > 0.8 
            ? Colors.orange 
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showEMIDetailsDialog(emi),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emi.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          emi.lenderName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (emi.category != 'other')
                          Text(
                            emi.category.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleEMIAction(value, emi),
                    itemBuilder: (context) => [
                      if (!emi.isCompleted)
                        const PopupMenuItem(
                          value: 'pay',
                          child: Row(
                            children: [
                              Icon(Icons.payment, size: 18),
                              SizedBox(width: 8),
                              Text('Pay EMI'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly EMI',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(emi.monthlyEMI),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remaining',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(emi.remainingAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (emi.nextDueDate != null && !emi.isCompleted)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Due',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _dateFormat.format(emi.nextDueDate!),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: ${emi.paidInstallments}/${emi.tenureMonths} installments',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(emi.progressPercentage * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: progressColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: emi.progressPercentage,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ],
              ),
              if (emi.isCompleted)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'COMPLETED ✓',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.account_balance,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No EMIs Added',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first EMI to start tracking loan payments using the floating + button',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleEMIAction(String action, EMI emi) {
    switch (action) {
      case 'pay':
        _showPayEMIDialog(emi);
        break;
      case 'edit':
        _showEditEMIDialog(emi);
        break;
      case 'delete':
        _showDeleteConfirmationDialog(emi);
        break;
    }
  }

  void _showCreateEMIDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateEMIDialog(),
    );
  }

  void _showEditEMIDialog(EMI emi) {
    showDialog(
      context: context,
      builder: (context) => CreateEMIDialog(emi: emi),
    );
  }

  void _showPayEMIDialog(EMI emi) {
    showDialog(
      context: context,
      builder: (context) => PayEMIDialog(emi: emi),
    );
  }

  void _showEMIDetailsDialog(EMI emi) {
    showDialog(
      context: context,
      builder: (context) => EMIDetailsDialog(emi: emi),
    );
  }

  void _showDeleteConfirmationDialog(EMI emi) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete EMI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${emi.name}"?'),
            const SizedBox(height: 8),
            if (!emi.isCompleted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This EMI is still active. Consider archiving instead of deleting.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteEMI(emi),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteEMI(EMI emi) async {
    try {
      await context.read<FinanceProvider>().deleteEMI(emi.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EMI "${emi.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Pay EMI Dialog
class PayEMIDialog extends StatefulWidget {
  final EMI emi;

  const PayEMIDialog({super.key, required this.emi});

  @override
  State<PayEMIDialog> createState() => _PayEMIDialogState();
}

class _PayEMIDialogState extends State<PayEMIDialog> {
  final _amountController = TextEditingController();
  String? _selectedVirtualBankId;
  bool _useCustomAmount = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.emi.monthlyEMI.toString();
    _selectedVirtualBankId = widget.emi.virtualBankId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pay EMI - ${widget.emi.name}'),
      content: Consumer<FinanceProvider>(
        builder: (context, financeProvider, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Custom Amount'),
                subtitle: const Text('Pay different amount than scheduled EMI'),
                value: _useCustomAmount,
                onChanged: (value) {
                  setState(() {
                    _useCustomAmount = value;
                    if (!value) {
                      _amountController.text = widget.emi.monthlyEMI.toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount',
                  prefixText: '₹ ',
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: TextInputType.number,
                enabled: _useCustomAmount,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVirtualBankId,
                decoration: const InputDecoration(
                  labelText: 'Pay from Virtual Bank (Optional)',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Main Balance'),
                  ),
                  ...financeProvider.virtualBanks.map((bank) {
                    return DropdownMenuItem<String>(
                      value: bank.id,
                      child: Text('${bank.name} (₹${NumberFormat('#,##,###').format(bank.balance)})'),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedVirtualBankId = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Installment:'),
                        Text('${widget.emi.paidInstallments + 1}/${widget.emi.tenureMonths}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Due Date:'),
                        Text(widget.emi.nextDueDate != null 
                            ? DateFormat('MMM dd, yyyy').format(widget.emi.nextDueDate!)
                            : 'N/A'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _payEMI,
          child: const Text('Pay Now'),
        ),
      ],
    );
  }

  void _payEMI() async {
    try {
      final amount = double.parse(_amountController.text);
      
      await context.read<FinanceProvider>().payEMIInstallment(
        widget.emi.id,
        customAmount: _useCustomAmount ? amount : null,
        virtualBankId: _selectedVirtualBankId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('EMI payment of ₹${NumberFormat('#,##,###').format(amount)} recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// EMI Details Dialog
class EMIDetailsDialog extends StatelessWidget {
  final EMI emi;

  const EMIDetailsDialog({super.key, required this.emi});

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'EMI Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('EMI Name', emi.name),
                    _buildDetailRow('Lender', emi.lenderName),
                    _buildDetailRow('Category', emi.category.replaceAll('_', ' ').toUpperCase()),
                    if (emi.description != null)
                      _buildDetailRow('Description', emi.description!),
                    
                    const Divider(height: 32),
                    
                    _buildDetailRow('Principal Amount', currencyFormat.format(emi.principalAmount)),
                    _buildDetailRow('Interest Rate', '${emi.interestRate}% p.a.'),
                    _buildDetailRow('Tenure', '${emi.tenureMonths} months'),
                    _buildDetailRow('Monthly EMI', currencyFormat.format(emi.monthlyEMI)),
                    _buildDetailRow('Total Amount', currencyFormat.format(emi.totalAmount)),
                    _buildDetailRow('Total Interest', currencyFormat.format(emi.totalInterest)),
                    
                    const Divider(height: 32),
                    
                    _buildDetailRow('Start Date', DateFormat('MMM dd, yyyy').format(emi.startDate)),
                    if (emi.nextDueDate != null)
                      _buildDetailRow('Next Due Date', DateFormat('MMM dd, yyyy').format(emi.nextDueDate!)),
                    _buildDetailRow('Paid Installments', '${emi.paidInstallments}/${emi.tenureMonths}'),
                    _buildDetailRow('Remaining Installments', '${emi.remainingInstallments}'),
                    _buildDetailRow('Paid Amount', currencyFormat.format(emi.paidAmount)),
                    _buildDetailRow('Remaining Amount', currencyFormat.format(emi.remainingAmount)),
                    
                    const SizedBox(height: 16),
                    
                    LinearProgressIndicator(
                      value: emi.progressPercentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        emi.isCompleted ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(emi.progressPercentage * 100).toStringAsFixed(1)}% Complete',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    
                    if (emi.autoDebit) ...[
                      const Divider(height: 32),
                      _buildDetailRow('Auto-Debit', 'Enabled'),
                      if (emi.autoDebitDay != null)
                        _buildDetailRow('Auto-Debit Day', '${emi.autoDebitDay} of every month'),
                    ],
                    
                    if (emi.virtualBankId != null) ...[
                      const Divider(height: 32),
                      Consumer<FinanceProvider>(
                        builder: (context, financeProvider, child) {
                          final virtualBank = financeProvider.virtualBanks
                              .where((bank) => bank.id == emi.virtualBankId)
                              .firstOrNull;
                          
                          return _buildDetailRow(
                            'Payment Source', 
                            virtualBank?.name ?? 'Unknown Virtual Bank',
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}