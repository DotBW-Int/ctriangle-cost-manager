import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/providers/finance_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/widgets/brand_logo.dart';
import '../core/theme/app_theme.dart';
import '../core/models/models.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late NumberFormat _currencyFormat;
  late String _currencySymbol;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize currency formatting
      _initializeCurrency();
      
      context.read<FinanceProvider>().initializeData();
      context.read<FinanceProvider>().processRecurringTransactions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeCurrency();
  }

  void _initializeCurrency() {
    try {
      final locale = Localizations.localeOf(context);
      print('Dashboard - Detected locale: ${locale.toString()}');
      print('Dashboard - Country code: ${locale.countryCode}');
      print('Dashboard - Language code: ${locale.languageCode}');
      
      // Force India locale for testing - you can change this based on your preference
      final targetLocale = 'en_IN'; // Change this to your preferred locale
      
      // Get currency formatter for India locale
      _currencyFormat = NumberFormat.currency(locale: targetLocale);
      
      // Try to get the currency symbol more reliably
      final simpleCurrencyFormat = NumberFormat.simpleCurrency(locale: targetLocale);
      _currencySymbol = simpleCurrencyFormat.currencySymbol;
      
      print('Dashboard - Currency symbol from locale: $_currencySymbol');
      
      // Enhanced fallback logic with India-specific handling
      if (_currencySymbol.isEmpty || _currencySymbol == 'INR') {
        // Get currency based on target locale
        if (targetLocale.contains('IN') || targetLocale.contains('hi')) {
          _currencySymbol = '₹';
          _currencyFormat = NumberFormat.currency(locale: targetLocale, symbol: '₹');
        } else {
          final currencyName = simpleCurrencyFormat.currencyName;
          switch (currencyName?.toUpperCase()) {
            case 'INR':
              _currencySymbol = '₹';
              break;
            case 'USD':
              _currencySymbol = '\$';
              break;
            case 'EUR':
              _currencySymbol = '€';
              break;
            case 'GBP':
              _currencySymbol = '£';
              break;
            case 'JPY':
              _currencySymbol = '¥';
              break;
            case 'CAD':
              _currencySymbol = 'C\$';
              break;
            case 'AUD':
              _currencySymbol = 'A\$';
              break;
            default:
              // Final fallback - default to INR for India
              _currencySymbol = '₹';
          }
        }
      }
      
      print('Dashboard - Final currency symbol: $_currencySymbol');
    } catch (e) {
      print('Dashboard - Currency initialization error: $e');
      // Ultimate fallback to INR for India
      _currencySymbol = '₹';
      _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    }
  }

  String _getCurrencyByCountry(String? countryCode) {
    switch (countryCode?.toUpperCase()) {
      case 'US':
        return '\$';
      case 'GB':
        return '£';
      case 'IN':
        return '₹';
      case 'JP':
        return '¥';
      case 'CA':
        return 'C\$';
      case 'AU':
        return 'A\$';
      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
        return '€';
      default:
        return '\$';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update currency format when rebuilding
    _initializeCurrency();
    
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  _buildVirtualBanksSection(),
                  const SizedBox(height: 16),
                  _buildQuickActionsSection(),
                  const SizedBox(height: 16),
                  _buildRecentTransactions(),
                  const SizedBox(height: 16),
                  _buildExpenseChart(),
                  const SizedBox(height: 16),
                  _buildFinancialInsights(),
                ]),
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

  Widget _buildAppBar() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        // Use theme background colors for consistency
        final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
        final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
        final iconColor = isDarkMode ? Colors.white70 : Colors.grey[600];
        
        return SliverAppBar(
          expandedHeight: 100,
          floating: false,
          pinned: true,
          backgroundColor: backgroundColor,
          surfaceTintColor: backgroundColor,
          shadowColor: Colors.transparent, // Remove shadow
          elevation: 0, // Remove elevation
          collapsedHeight: 70,
          flexibleSpace: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Calculate the shrink offset (0.0 = fully expanded, 1.0 = fully collapsed)
              final double shrinkOffset = 
                  (constraints.maxHeight - kToolbarHeight - MediaQuery.of(context).padding.top) / 
                  (100 - kToolbarHeight - MediaQuery.of(context).padding.top);
              
              final bool isCollapsed = shrinkOffset <= 0.0;
              
              return Container(
                decoration: BoxDecoration(
                  color: backgroundColor, // Use theme background
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side - Logo and greeting
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo - scales down when collapsed
                              CTriangleLogo(
                                fontSize: isCollapsed ? 20 : 28,
                                showFullName: !isCollapsed,
                              ),
                              // Greeting - fades out when collapsed
                              if (!isCollapsed) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Good ${_getGreeting()}!',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Right side - Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Clear Data Button
                            IconButton(
                              onPressed: _showClearDataDialog,
                              icon: Icon(
                                Icons.delete_sweep,
                                color: iconColor,
                                size: isCollapsed ? 20 : 24,
                              ),
                              tooltip: 'Clear All Data',
                            ),
                            // Theme Toggle Button with proper colors
                            IconButton(
                              onPressed: () => themeProvider.toggleTheme(),
                              icon: Icon(
                                themeProvider.isDarkMode 
                                    ? Icons.light_mode 
                                    : Icons.dark_mode,
                                color: themeProvider.isDarkMode 
                                    ? Colors.amber // Sun icon in dark mode
                                    : Colors.grey[700], // Moon icon in light mode
                                size: isCollapsed ? 20 : 24,
                              ),
                              tooltip: 'Toggle Theme',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Data'),
          content: const Text(
            'Are you sure you want to clear all data? This will delete:\n\n'
            '• All transactions\n'
            '• All virtual banks\n'
            '• All budgets\n\n'
            'This action cannot be undone.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearAllData();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Clear All Data'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAllData() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Clearing all data...'),
              ],
            ),
          );
        },
      );

      // Clear all data
      await context.read<FinanceProvider>().clearAllData();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data cleared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBalanceCard() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
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
                  Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white70,
                    size: 24,
                  ),
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
                    child: _buildBalanceInfo(
                      'Income',
                      financeProvider.transactions
                          .where((t) => t.type == 'income')
                          .fold(0.0, (sum, t) => sum + t.amount),
                      Icons.trending_up,
                      Colors.green[300]!,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBalanceInfo(
                      'Expenses',
                      financeProvider.transactions
                          .where((t) => t.type == 'expense')
                          .fold(0.0, (sum, t) => sum + t.amount),
                      Icons.trending_down,
                      Colors.red[300]!,
                    ),
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
    return Container(
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _currencyFormat.format(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualBanksSection() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        if (financeProvider.virtualBanks.isEmpty) {
          return _buildEmptyVirtualBanks();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Virtual Banks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => _showCreateVirtualBankDialog(),
                  child: const Text('Add New'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: financeProvider.virtualBanks.length,
                itemBuilder: (context, index) {
                  final bank = financeProvider.virtualBanks[index];
                  return _buildVirtualBankCard(bank);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVirtualBankCard(VirtualBank bank) {
    final color = Color(int.parse(bank.color.replaceFirst('#', '0xFF')));
    
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bank.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                _getIconData(bank.icon),
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(bank.balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Goal: ${_currencyFormat.format(bank.targetAmount)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: bank.progressPercentage,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${(bank.progressPercentage * 100).toStringAsFixed(0)}% Complete',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyVirtualBanks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.account_balance,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Create Virtual Banks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save for specific goals like insurance, emergency fund, or vacation',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              text: 'Create Your First Bank',
              onPressed: () => _showCreateVirtualBankDialog(),
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Add Expense',
                Icons.remove_circle_outline,
                Colors.red,
                () => _showAddTransactionBottomSheet(type: 'expense'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Add Income',
                Icons.add_circle_outline,
                Colors.green,
                () => _showAddTransactionBottomSheet(type: 'income'),
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
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
        final recentTransactions = financeProvider.transactions.take(5).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (recentTransactions.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to transactions screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All transactions screen coming soon!')),
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
        child: Center( // Added Center widget for proper alignment
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center, // Center text alignment
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking your finances by adding your first transaction',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Center( // Center the button
                child: GradientButton(
                  text: 'Add Transaction',
                  onPressed: () => _showAddTransactionBottomSheet(),
                  width: 160,
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
            isExpense ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${transaction.category} • ${DateFormat('MMM dd').format(transaction.date)}',
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'} ${_currencyFormat.format(transaction.amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

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

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses by Category',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieChartSections(snapshot.data!),
                          centerSpaceRadius: 60,
                          sectionsSpace: 2,
                        ),
                      ),
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
      AppTheme.primaryBlue,
      AppTheme.lightBlue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
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
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
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
                    Icon(
                      Icons.lightbulb_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Financial Insights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                        child: Text(
                          insight,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'savings':
        return Icons.savings;
      case 'security':
        return Icons.security;
      case 'flight':
        return Icons.flight;
      case 'home':
        return Icons.home;
      case 'car':
        return Icons.directions_car;
      default:
        return Icons.account_balance;
    }
  }

  void _showAddTransactionBottomSheet({String? type}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTransactionBottomSheet(initialType: type),
    );
  }

  void _showCreateVirtualBankDialog() {
    // TODO: Implement create virtual bank dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create virtual bank feature coming soon!')),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }
}