import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/providers/finance_provider.dart';
import '../core/models/models.dart';
import '../core/widgets/create_virtual_bank_dialog.dart';
import '../core/theme/app_theme.dart';

enum VirtualBankSortBy {
  name,
  balance,
  targetAmount,
  progress,
  monthlyDue,
  timeRemaining,
}

enum VirtualBankFilter {
  all,
  active,
  completed,
  nearCompletion,
  overdue,
}

class VirtualBanksScreen extends StatefulWidget {
  const VirtualBanksScreen({super.key});

  @override
  State<VirtualBanksScreen> createState() => _VirtualBanksScreenState();
}

class _VirtualBanksScreenState extends State<VirtualBanksScreen> {
  final TextEditingController _searchController = TextEditingController();
  VirtualBankSortBy _sortBy = VirtualBankSortBy.name;
  bool _isAscending = true;
  VirtualBankFilter _filter = VirtualBankFilter.all;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    
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
                text: 'Triangle Virtual Banks',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, financeProvider, child) {
          final allVirtualBanks = financeProvider.virtualBanks;
          final filteredAndSortedBanks = _getFilteredAndSortedBanks(allVirtualBanks);
          
          if (allVirtualBanks.isEmpty) {
            return _buildEmptyState(context);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEnhancedOverviewCard(allVirtualBanks, currencyFormat, context),
                const SizedBox(height: 24),
                _buildSearchAndSort(),
                const SizedBox(height: 16),
                _buildActiveFiltersChips(),
                const SizedBox(height: 16),
                _buildBanksList(filteredAndSortedBanks, currencyFormat, context),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateVirtualBankDialog(context),
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
    );
  }

  List<VirtualBank> _getFilteredAndSortedBanks(List<VirtualBank> banks) {
    // Apply search filter
    var filteredBanks = banks.where((bank) {
      if (_searchQuery.isEmpty) return true;
      return bank.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (bank.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    // Apply status filter
    filteredBanks = filteredBanks.where((bank) {
      switch (_filter) {
        case VirtualBankFilter.all:
          return true;
        case VirtualBankFilter.active:
          return bank.progressPercentage < 1.0;
        case VirtualBankFilter.completed:
          return bank.progressPercentage >= 1.0;
        case VirtualBankFilter.nearCompletion:
          return bank.progressPercentage >= 0.8 && bank.progressPercentage < 1.0;
        case VirtualBankFilter.overdue:
          return _getMonthsRemaining(bank) < 0;
      }
    }).toList();

    // Apply sorting
    filteredBanks.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case VirtualBankSortBy.name:
          comparison = a.name.compareTo(b.name);
          break;
        case VirtualBankSortBy.balance:
          comparison = a.balance.compareTo(b.balance);
          break;
        case VirtualBankSortBy.targetAmount:
          comparison = a.targetAmount.compareTo(b.targetAmount);
          break;
        case VirtualBankSortBy.progress:
          comparison = a.progressPercentage.compareTo(b.progressPercentage);
          break;
        case VirtualBankSortBy.monthlyDue:
          comparison = _getMonthlyDue(a).compareTo(_getMonthlyDue(b));
          break;
        case VirtualBankSortBy.timeRemaining:
          comparison = _getMonthsRemaining(a).compareTo(_getMonthsRemaining(b));
          break;
      }
      
      return _isAscending ? comparison : -comparison;
    });

    return filteredBanks;
  }

  double _getMonthlyDue(VirtualBank bank) {
    if (bank.progressPercentage >= 1.0) return 0.0;
    
    final remaining = bank.targetAmount - bank.balance;
    final monthsLeft = _getMonthsRemaining(bank);
    
    if (monthsLeft <= 0) return remaining; // All due now if overdue
    return remaining / monthsLeft;
  }

  int _getMonthsRemaining(VirtualBank bank) {
    if (bank.targetDate == null) return 12; // Default to 12 months if no target date
    
    final now = DateTime.now();
    final target = bank.targetDate!;
    
    return ((target.year - now.year) * 12 + target.month - now.month);
  }

  double _getMonthlyRequired(VirtualBank bank) {
    if (bank.progressPercentage >= 1.0) return 0.0;
    
    final remaining = bank.targetAmount - bank.balance;
    final monthsLeft = _getMonthsRemaining(bank);
    
    if (monthsLeft <= 0) return remaining; // All due now if overdue
    return remaining / monthsLeft;
  }

  Widget _buildSearchAndSort() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search virtual banks...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<VirtualBankSortBy>(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAscending ? Icons.sort : Icons.sort,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Icon(
                  _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Theme.of(context).primaryColor,
                  size: 16,
                ),
              ],
            ),
          ),
          onSelected: (VirtualBankSortBy sortBy) {
            setState(() {
              if (_sortBy == sortBy) {
                _isAscending = !_isAscending;
              } else {
                _sortBy = sortBy;
                _isAscending = true;
              }
            });
          },
          itemBuilder: (context) => [
            _buildSortMenuItem(VirtualBankSortBy.name, 'Name'),
            _buildSortMenuItem(VirtualBankSortBy.balance, 'Balance'),
            _buildSortMenuItem(VirtualBankSortBy.targetAmount, 'Target Amount'),
            _buildSortMenuItem(VirtualBankSortBy.progress, 'Progress'),
            _buildSortMenuItem(VirtualBankSortBy.monthlyDue, 'Monthly Due'),
            _buildSortMenuItem(VirtualBankSortBy.timeRemaining, 'Time Remaining'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<VirtualBankSortBy> _buildSortMenuItem(VirtualBankSortBy sortBy, String title) {
    return PopupMenuItem<VirtualBankSortBy>(
      value: sortBy,
      child: Row(
        children: [
          Icon(
            _getSortIcon(sortBy),
            size: 18,
            color: _sortBy == sortBy ? Theme.of(context).primaryColor : null,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _sortBy == sortBy ? Theme.of(context).primaryColor : null,
              fontWeight: _sortBy == sortBy ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (_sortBy == sortBy) ...[
            const Spacer(),
            Icon(
              _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getSortIcon(VirtualBankSortBy sortBy) {
    switch (sortBy) {
      case VirtualBankSortBy.name:
        return Icons.sort_by_alpha;
      case VirtualBankSortBy.balance:
        return Icons.account_balance_wallet;
      case VirtualBankSortBy.targetAmount:
        return Icons.flag;
      case VirtualBankSortBy.progress:
        return Icons.trending_up;
      case VirtualBankSortBy.monthlyDue:
        return Icons.payment;
      case VirtualBankSortBy.timeRemaining:
        return Icons.schedule;
    }
  }

  Widget _buildActiveFiltersChips() {
    List<Widget> chips = [];

    if (_filter != VirtualBankFilter.all) {
      chips.add(
        FilterChip(
          label: Text(_getFilterDisplayName(_filter)),
          selected: true,
          onSelected: (selected) {
            setState(() {
              _filter = VirtualBankFilter.all;
            });
          },
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            setState(() {
              _filter = VirtualBankFilter.all;
            });
          },
        ),
      );
    }

    if (_searchQuery.isNotEmpty) {
      chips.add(
        FilterChip(
          label: Text('Search: "$_searchQuery"'),
          selected: true,
          onSelected: (selected) {
            _searchController.clear();
            setState(() {
              _searchQuery = '';
            });
          },
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () {
            _searchController.clear();
            setState(() {
              _searchQuery = '';
            });
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      children: chips,
    );
  }

  String _getFilterDisplayName(VirtualBankFilter filter) {
    switch (filter) {
      case VirtualBankFilter.all:
        return 'All';
      case VirtualBankFilter.active:
        return 'Active';
      case VirtualBankFilter.completed:
        return 'Completed';
      case VirtualBankFilter.nearCompletion:
        return 'Near Completion';
      case VirtualBankFilter.overdue:
        return 'Overdue';
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Virtual Banks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Status Filter',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: VirtualBankFilter.values.map((filter) {
                return FilterChip(
                  label: Text(_getFilterDisplayName(filter)),
                  selected: _filter == filter,
                  onSelected: (selected) {
                    setState(() {
                      _filter = selected ? filter : VirtualBankFilter.all;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filter = VirtualBankFilter.all;
                    _searchController.clear();
                    _searchQuery = '';
                    _sortBy = VirtualBankSortBy.name;
                    _isAscending = true;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear All Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedOverviewCard(List<VirtualBank> banks, NumberFormat currencyFormat, BuildContext context) {
    final totalBalance = banks.fold(0.0, (sum, bank) => sum + bank.balance);
    final totalTarget = banks.fold(0.0, (sum, bank) => sum + bank.targetAmount);
    final completedBanks = banks.where((bank) => bank.progressPercentage >= 1.0).length;
    final activeBanks = banks.where((bank) => bank.progressPercentage < 1.0).length;
    final totalProgressPercentage = totalTarget > 0 ? (totalBalance / totalTarget * 100) : 0.0;
    
    // Calculate monthly requirements - simplified version without auto-save
    final totalMonthlyRequired = banks.fold(0.0, (sum, bank) => sum + _getMonthlyRequired(bank));
    
    // Status categories
    final nearCompletionBanks = banks.where((bank) => bank.progressPercentage >= 0.8 && bank.progressPercentage < 1.0).length;
    final overdueBanks = banks.where((bank) => _getMonthsRemaining(bank) < 0 && bank.progressPercentage < 1.0).length;
    final onTrackBanks = banks.where((bank) => 
        bank.progressPercentage < 0.8 && _getMonthsRemaining(bank) >= 0).length;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Virtual Banks Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Primary metrics row - similar to EMI screen
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    'Monthly Required',
                    currencyFormat.format(totalMonthlyRequired),
                    Icons.payment,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewItem(
                    'Total Banks',
                    '${banks.length}',
                    Icons.account_balance,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Progress and completion row
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    'Total Saved',
                    currencyFormat.format(totalBalance),
                    Icons.savings,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewItem(
                    'Overall Progress',
                    '${totalProgressPercentage.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    totalProgressPercentage >= 100 ? Colors.green : 
                    totalProgressPercentage >= 80 ? Colors.orange : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Status breakdown row - show distribution
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    'Completed',
                    '$completedBanks',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOverviewItem(
                    'Active',
                    '$activeBanks',
                    Icons.play_circle,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            // Status breakdown row - show distribution
            if (banks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOverviewItem(
                      'On Track',
                      '$onTrackBanks',
                      Icons.track_changes,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOverviewItem(
                      'Near Goal',
                      '$nearCompletionBanks',
                      Icons.flag,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
            
            // Warning row if there are issues
            if (overdueBanks > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildOverviewItem(
                      'Overdue',
                      '$overdueBanks',
                      Icons.warning,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOverviewItem(
                      'Remaining',
                      currencyFormat.format(totalTarget - totalBalance),
                      Icons.trending_down,
                      Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
            
            // Overall Progress Bar with better labeling
            if (totalTarget > 0) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Savings Progress',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${currencyFormat.format(totalBalance)} / ${currencyFormat.format(totalTarget)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[300],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalProgressPercentage / 100,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      totalProgressPercentage >= 100 ? Colors.green : 
                      totalProgressPercentage >= 80 ? Colors.orange : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${totalProgressPercentage.toStringAsFixed(1)}% of total savings goal achieved',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            // Monthly requirement insight
            if (totalMonthlyRequired > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You need to save ${currencyFormat.format(totalMonthlyRequired)} per month to meet all your virtual banking goals on time.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
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

  Widget _buildOverviewItem(String title, String value, IconData icon, Color color) {
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

  Widget _buildBanksList(List<VirtualBank> banks, NumberFormat currencyFormat, BuildContext context) {
    if (banks.isEmpty) {
      return _buildNoResultsState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Virtual Banks (${banks.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (banks.length > 1)
              Text(
                'Sorted by ${_getSortDisplayName(_sortBy)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...banks.map((bank) => _buildEnhancedVirtualBankCard(bank, currencyFormat, context)),
      ],
    );
  }

  String _getSortDisplayName(VirtualBankSortBy sortBy) {
    switch (sortBy) {
      case VirtualBankSortBy.name:
        return 'Name';
      case VirtualBankSortBy.balance:
        return 'Balance';
      case VirtualBankSortBy.targetAmount:
        return 'Target Amount';
      case VirtualBankSortBy.progress:
        return 'Progress';
      case VirtualBankSortBy.monthlyDue:
        return 'Monthly Due';
      case VirtualBankSortBy.timeRemaining:
        return 'Time Remaining';
    }
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No banks found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Virtual Banks',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create virtual banks to save for specific goals using the floating + button',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedVirtualBankCard(VirtualBank bank, NumberFormat currencyFormat, BuildContext context) {
    final color = Color(int.parse(bank.color.replaceFirst('#', '0xFF')));
    final monthlyDue = _getMonthlyDue(bank);
    final monthsRemaining = _getMonthsRemaining(bank);
    final isOverdue = monthsRemaining < 0;
    final isNearCompletion = bank.progressPercentage >= 0.8 && bank.progressPercentage < 1.0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bank.description != null)
                          Text(
                            bank.description!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isNearCompletion && !isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'NEAR GOAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _getIconData(bank.icon),
                        color: Colors.white,
                        size: 32,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Balance and Target row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Balance',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          currencyFormat.format(bank.balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Target Amount',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          currencyFormat.format(bank.targetAmount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Monthly due and time remaining row
              if (bank.progressPercentage < 1.0) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Due',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            currencyFormat.format(monthlyDue),
                            style: TextStyle(
                              color: isOverdue ? Colors.red[200] : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time Remaining',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            isOverdue 
                                ? '${monthsRemaining.abs()} months overdue'
                                : monthsRemaining == 0
                                    ? 'Due this month'
                                    : '$monthsRemaining months left',
                            style: TextStyle(
                              color: isOverdue ? Colors.red[200] : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: ${currencyFormat.format(bank.balance)} / ${currencyFormat.format(bank.targetAmount)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(bank.progressPercentage * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: bank.progressPercentage,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              ),
              if (bank.progressPercentage >= 1.0)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'GOAL ACHIEVED! ✓',
                    style: TextStyle(
                      color: Colors.white,
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

  void _showCreateVirtualBankDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateVirtualBankDialog(),
    );
  }
}