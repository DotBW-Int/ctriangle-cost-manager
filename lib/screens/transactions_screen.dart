import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/providers/finance_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/models/models.dart';

class TransactionsScreen extends StatefulWidget {
  final String? initialFilter; // 'income', 'expense', or null for all

  const TransactionsScreen({super.key, this.initialFilter});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedFilter = 'all';
  String _sortBy = 'date';
  String _sortOrder = 'desc';
  String _timeFilter = 'month';
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedYear = DateTime.now();
  double _minAmount = 0;
  double _maxAmount = double.infinity;
  bool _showFilters = false;
  
  late NumberFormat _currencyFormat;
  
  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'all';
    _initializeCurrency();
  }

  void _initializeCurrency() {
    _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildFilterChips(),
                  if (_showFilters) ...[
                    const SizedBox(height: 16),
                    _buildAdvancedFilters(),
                  ],
                  const SizedBox(height: 16),
                  _buildMonthlySummary(),
                  const SizedBox(height: 16),
                  _buildTransactionsList(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
      shadowColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.arrow_back_ios,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'All Transactions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      ),
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
          icon: Icon(
            _showFilters ? Icons.filter_list_off : Icons.filter_list,
            color: _showFilters ? AppTheme.primaryBlue : null,
          ),
          tooltip: 'Toggle Filters',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            setState(() {
              final parts = value.split('_');
              _sortBy = parts[0];
              _sortOrder = parts[1];
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'date_desc',
              child: Text('Date (Newest First)'),
            ),
            const PopupMenuItem(
              value: 'date_asc',
              child: Text('Date (Oldest First)'),
            ),
            const PopupMenuItem(
              value: 'amount_desc',
              child: Text('Amount (High to Low)'),
            ),
            const PopupMenuItem(
              value: 'amount_asc',
              child: Text('Amount (Low to High)'),
            ),
          ],
          icon: const Icon(Icons.sort),
          tooltip: 'Sort Options',
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _selectedFilter == 'all',
          onSelected: (_) => setState(() => _selectedFilter = 'all'),
        ),
        FilterChip(
          label: const Text('Income'),
          selected: _selectedFilter == 'income',
          onSelected: (_) => setState(() => _selectedFilter = 'income'),
          selectedColor: Colors.green.withOpacity(0.2),
        ),
        FilterChip(
          label: const Text('Expense'),
          selected: _selectedFilter == 'expense',
          onSelected: (_) => setState(() => _selectedFilter = 'expense'),
          selectedColor: Colors.red.withOpacity(0.2),
        ),
        FilterChip(
          label: const Text('Recurring'),
          selected: _selectedFilter == 'recurring',
          onSelected: (_) => setState(() => _selectedFilter = 'recurring'),
          selectedColor: Colors.orange.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Filters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _timeFilter,
                    decoration: const InputDecoration(
                      labelText: 'Time Period',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'week', child: Text('This Week')),
                      DropdownMenuItem(value: 'month', child: Text('This Month')),
                      DropdownMenuItem(value: 'year', child: Text('This Year')),
                      DropdownMenuItem(value: 'all', child: Text('All Time')),
                    ],
                    onChanged: (value) => setState(() => _timeFilter = value!),
                  ),
                ),
                const SizedBox(width: 12),
                if (_timeFilter == 'month')
                  Expanded(
                    child: InkWell(
                      onTap: _selectMonth,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(DateFormat('MMM yyyy').format(_selectedMonth)),
                      ),
                    ),
                  ),
                if (_timeFilter == 'year')
                  Expanded(
                    child: InkWell(
                      onTap: _selectYear,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(_selectedYear.year.toString()),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Min Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _minAmount = double.tryParse(value) ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Max Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _maxAmount = double.tryParse(value) ?? double.infinity;
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

  Widget _buildMonthlySummary() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        final summary = financeProvider.getMonthlyTransactionSummary(_selectedMonth);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMM yyyy').format(_selectedMonth),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Income',
                        summary['totalIncome'],
                        Icons.trending_up,
                        Colors.green,
                        () => _navigateToFilteredView('income'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Expenses',
                        summary['totalExpenses'],
                        Icons.trending_down,
                        Colors.red,
                        () => _navigateToFilteredView('expense'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: summary['netAmount'] >= 0 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Amount',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: summary['netAmount'] >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(summary['netAmount']),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: summary['netAmount'] >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, double amount, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _currencyFormat.format(amount),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        List<Transaction> filteredTransactions = _getFilteredTransactions(financeProvider.transactions);
        
        if (filteredTransactions.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions (${filteredTransactions.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getSortDescription(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final transaction = filteredTransactions[index];
                return _buildTransactionItem(transaction);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isIncome = transaction.type == 'income' || 
                   (transaction.type == 'recurring' && _isIncomeCategory(transaction.category));
    final color = isIncome ? Colors.green : Colors.red;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction.category} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
            ),
            if (transaction.isRecurring)
              Text(
                'Recurring ${transaction.recurringFrequency}',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isIncome ? '+' : '-'} ${_currencyFormat.format(transaction.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (transaction.virtualBankId != null)
              Text(
                'Virtual Bank',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Transactions Found',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters or add some transactions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    List<Transaction> filtered = transactions.where((t) {
      // Filter by type
      if (_selectedFilter != 'all') {
        if (_selectedFilter == 'income' && !_isIncomeTransaction(t)) return false;
        if (_selectedFilter == 'expense' && _isIncomeTransaction(t)) return false;
        if (_selectedFilter == 'recurring' && !t.isRecurring) return false;
      }

      // Filter by time
      final now = DateTime.now();
      switch (_timeFilter) {
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          if (t.date.isBefore(weekStart)) return false;
          break;
        case 'month':
          final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
          final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
          if (t.date.isBefore(monthStart) || t.date.isAfter(monthEnd)) return false;
          break;
        case 'year':
          final yearStart = DateTime(_selectedYear.year, 1, 1);
          final yearEnd = DateTime(_selectedYear.year, 12, 31);
          if (t.date.isBefore(yearStart) || t.date.isAfter(yearEnd)) return false;
          break;
      }

      // Filter by amount
      if (t.amount < _minAmount || t.amount > _maxAmount) return false;

      return true;
    }).toList();

    // Sort transactions
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'date':
          comparison = a.date.compareTo(b.date);
          break;
        case 'amount':
          comparison = a.amount.compareTo(b.amount);
          break;
      }
      return _sortOrder == 'desc' ? -comparison : comparison;
    });

    return filtered;
  }

  bool _isIncomeTransaction(Transaction transaction) {
    return transaction.type == 'income' || 
           (transaction.type == 'recurring' && _isIncomeCategory(transaction.category));
  }

  bool _isIncomeCategory(String category) {
    const incomeCategories = [
      'Salary', 'Freelance', 'Business', 'Investments', 'Rental Income',
      'Dividends', 'Interest', 'Bonus', 'Tax Refund', 'Gifts', 'Other Income'
    ];
    return incomeCategories.contains(category);
  }

  String _getSortDescription() {
    final sortType = _sortBy == 'date' ? 'Date' : 'Amount';
    final order = _sortOrder == 'desc' ? 'Newest First' : 'Oldest First';
    return 'Sorted by $sortType ($order)';
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  Future<void> _selectYear() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedYear,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedYear = picked;
      });
    }
  }

  void _navigateToFilteredView(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildTransactionDetailsSheet(transaction),
    );
  }

  Widget _buildTransactionDetailsSheet(Transaction transaction) {
    final isIncome = _isIncomeTransaction(transaction);
    final color = isIncome ? Colors.green : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'} ${_currencyFormat.format(transaction.amount)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Category', transaction.category),
          _buildDetailRow('Date', DateFormat('EEEE, MMM dd, yyyy').format(transaction.date)),
          _buildDetailRow('Type', transaction.type.toUpperCase()),
          if (transaction.isRecurring) ...[
            _buildDetailRow('Frequency', transaction.recurringFrequency ?? 'N/A'),
            if (transaction.nextDueDate != null)
              _buildDetailRow('Next Due', DateFormat('MMM dd, yyyy').format(transaction.nextDueDate!)),
          ],
          if (transaction.virtualBankId != null)
            _buildDetailRow('Virtual Bank', 'Yes'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Navigate to edit transaction
                  },
                  child: const Text('Edit'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
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