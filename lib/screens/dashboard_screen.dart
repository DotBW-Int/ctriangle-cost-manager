import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/providers/finance_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/add_transaction_bottom_sheet.dart';
import '../core/widgets/transaction_details_dialog.dart';
import '../screens/transactions_screen.dart';
import '../screens/emi_screen.dart';
import '../screens/virtual_banks_screen.dart';
import '../screens/settings_screen.dart';
import '../core/widgets/create_virtual_bank_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> 
    with TickerProviderStateMixin {
  late NumberFormat _currencyFormat;
  late String _currencySymbol;
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _progressAnimationController.repeat();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrency();
      context.read<FinanceProvider>().initializeData();
      context.read<FinanceProvider>().processRecurringTransactions();
    });
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeCurrency();
  }

  void _initializeCurrency() {
    try {
      final targetLocale = 'en_IN';
      _currencyFormat = NumberFormat.currency(locale: targetLocale);
      final simpleCurrencyFormat = NumberFormat.simpleCurrency(locale: targetLocale);
      _currencySymbol = simpleCurrencyFormat.currencySymbol;
      
      if (_currencySymbol.isEmpty || _currencySymbol == 'INR') {
        _currencySymbol = '₹';
        _currencyFormat = NumberFormat.currency(locale: targetLocale, symbol: '₹');
      }
    } catch (e) {
      _currencySymbol = '₹';
      _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    }
  }

  bool _isIncomeCategory(String category) {
    const incomeCategories = [
      'Salary', 'Freelance', 'Business', 'Investments', 'Rental Income',
      'Dividends', 'Interest', 'Bonus', 'Tax Refund', 'Gifts', 'Other Income'
    ];
    return incomeCategories.contains(category);
  }

  @override
  Widget build(BuildContext context) {
    _initializeCurrency();
    
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildFixedAppBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      _buildBalanceCard(),
                      const SizedBox(height: 16),
                      _buildQuickActionsSection(),
                      const SizedBox(height: 16),
                      _buildRecentTransactions(),
                      const SizedBox(height: 16),
                      _buildExpenseChart(),
                      const SizedBox(height: 16),
                      _buildFinancialInsights(),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionBottomSheet(),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFixedAppBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
        final iconColor = isDarkMode ? Colors.white70 : Colors.grey[600];
        
        return Container(
          height: 70,
          decoration: BoxDecoration(color: backgroundColor),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'C',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            TextSpan(
                              text: 'T',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 35,
                        child: _buildAnimatedProgressLine(),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _navigateToSettings(),
                      icon: Icon(Icons.person_outline, color: iconColor, size: 20),
                      tooltip: 'Profile & Settings',
                    ),
                    IconButton(
                      onPressed: () => themeProvider.toggleTheme(),
                      icon: Icon(
                        themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: themeProvider.isDarkMode ? Colors.amber : Colors.grey[700],
                        size: 20,
                      ),
                      tooltip: 'Toggle Theme',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedProgressLine() {
    return Container(
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            final containerWidth = 35.0;
            final lineWidth = 20.0;
            final position = (_progressAnimation.value + 1.0) / 2.0;
            final leftPosition = (position * (containerWidth + lineWidth)) - lineWidth;
            
            return Container(
              width: containerWidth,
              height: 3,
              child: Stack(
                children: [
                  Positioned(
                    left: leftPosition,
                    child: Container(
                      width: lineWidth,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            AppTheme.primaryBlue.withOpacity(0.3),
                            AppTheme.primaryBlue,
                            AppTheme.lightBlue,
                            AppTheme.primaryBlue.withOpacity(0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        final totalIncome = financeProvider.transactions
            .where((t) => t.type == 'income' || 
                         (t.type == 'recurring' && _isIncomeCategory(t.category)))
            .fold(0.0, (sum, t) => sum + t.amount);
            
        final totalExpenses = financeProvider.transactions
            .where((t) => t.type == 'expense' || 
                         (t.type == 'recurring' && !_isIncomeCategory(t.category)))
            .fold(0.0, (sum, t) => sum + t.amount);
        
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(Icons.account_balance_wallet, color: Colors.white70, size: 24),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFormat.format(financeProvider.totalBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildBalanceInfo('Income', totalIncome, Icons.trending_up, Colors.green[300]!),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBalanceInfo('Expenses', totalExpenses, Icons.trending_down, Colors.red[300]!),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceInfo(String title, double amount, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TransactionsScreen(
              initialFilter: title.toLowerCase() == 'income' ? 'income' : 'expense',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    _currencyFormat.format(amount),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Add Expense', Icons.remove_circle_outline, Colors.red,
                () => _showAddTransactionBottomSheet(type: 'expense'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Add Income', Icons.add_circle_outline, Colors.green,
                () => _showAddTransactionBottomSheet(type: 'income'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Manage EMIs', Icons.credit_card, AppTheme.primaryBlue,
                () => _navigateToEMIScreen(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Virtual Banks', Icons.account_balance, Colors.purple,
                () => _navigateToVirtualBanksScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              // Only show counts for status/navigation actions (EMIs and Virtual Banks)
              if (title == 'Manage EMIs')
                Consumer<FinanceProvider>(
                  builder: (context, financeProvider, child) {
                    final emiCount = financeProvider.emis.length;
                    return Text('$emiCount EMIs', style: TextStyle(fontSize: 12, color: Colors.grey[600]));
                  },
                )
              else if (title == 'Virtual Banks')
                Consumer<FinanceProvider>(
                  builder: (context, financeProvider, child) {
                    final bankCount = financeProvider.virtualBanks.length;
                    return Text('$bankCount Banks', style: TextStyle(fontSize: 12, color: Colors.grey[600]));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        // Show only last 7 transactions in dashboard
        final recentTransactions = financeProvider.transactions.take(7).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (recentTransactions.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const TransactionsScreen()),
                      );
                    },
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentTransactions.isEmpty)
              _buildEmptyTransactions()
            else
              ...recentTransactions.map((transaction) => _buildTransactionItem(transaction)),
          ],
        );
      },
    );
  }

  Widget _buildEmptyTransactions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                'No Transactions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking your finances by using the floating + button',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isExpense = transaction.type == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    
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
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            // Show transaction number if available
            if (transaction.transactionNumber != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${transaction.transactionNumber}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                transaction.description,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${transaction.category} • ${DateFormat('MMM dd').format(transaction.date)}',
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'} ${_currencyFormat.format(transaction.amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        onTap: () => TransactionDetailsDialog.show(
          context: context,
          transaction: transaction,
          currencyFormat: _currencyFormat,
        ),
      ),
    );
  }

  // Add the missing methods for expense chart and financial insights
  Widget _buildExpenseChart() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        return FutureBuilder<Map<String, double>>(
          future: financeProvider.getExpensesByCategory(
            startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
            endDate: DateTime.now(),
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final data = snapshot.data!;
            final sortedEntries = data.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses by Category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: _buildPieChartSections(data),
                                centerSpaceRadius: 60,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Categories',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...sortedEntries.take(4).map((entry) => 
                                _buildCategoryLegend(entry.key, entry.value, data)
                              ),
                              if (sortedEntries.length > 4)
                                Text(
                                  '+ ${sortedEntries.length - 4} more',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> data) {
    final colors = [
      AppTheme.primaryBlue, AppTheme.lightBlue, Colors.green, Colors.orange,
      Colors.purple, Colors.red, Colors.teal, Colors.amber,
    ];

    int index = 0;
    return data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      
      return PieChartSectionData(
        value: entry.value,
        title: '${((entry.value / data.values.fold(0.0, (a, b) => a + b)) * 100).toStringAsFixed(0)}%',
        color: color,
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildCategoryLegend(String category, double amount, Map<String, double> allData) {
    final colors = [
      AppTheme.primaryBlue, AppTheme.lightBlue, Colors.green, Colors.orange,
      Colors.purple, Colors.red, Colors.teal, Colors.amber,
    ];
    
    final index = allData.keys.toList().indexOf(category);
    final color = colors[index % colors.length];
    final totalAmount = allData.values.fold(0.0, (a, b) => a + b);
    final percentage = (amount / totalAmount * 100).toStringAsFixed(0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_currencyFormat.format(amount)} ($percentage%)',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialInsights() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        final insights = financeProvider.getFinancialInsights();
        final insightsList = insights['insights'] as List<String>;

        if (insightsList.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Financial Insights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...insightsList.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(insight, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTransactionBottomSheet({String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionBottomSheet(initialType: type),
    );
  }

  void _navigateToSettings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  void _navigateToEMIScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const EMIScreen()));
  }

  void _navigateToVirtualBanksScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const VirtualBanksScreen()));
  }
}