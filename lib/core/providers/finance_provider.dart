import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../database/database_helper.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FinanceProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Uuid _uuid = const Uuid();

  List<Transaction> _transactions = [];
  List<VirtualBank> _virtualBanks = [];
  List<Budget> _budgets = [];
  List<EMI> _emis = [];
  double _totalBalance = 0.0;
  double _totalIncome = 0.0;
  double _totalExpenses = 0.0;

  // Getters
  List<Transaction> get transactions => _transactions;
  List<VirtualBank> get virtualBanks => _virtualBanks;
  List<Budget> get budgets => _budgets;
  List<EMI> get emis => _emis;
  double get totalBalance => _totalBalance;
  double get totalIncome => _totalIncome;
  double get totalExpenses => _totalExpenses;

  // Static category lists (can be extended dynamically)
  static List<String> expenseCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Travel',
    'Insurance',
    'Groceries',
    'Gas & Fuel',
    'Home & Garden',
    'Personal Care',
    'Gifts & Donations',
    'Business Services',
    'Taxes',
    'Miscellaneous',
  ];

  static List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Business',
    'Investments',
    'Rental Income',
    'Dividends',
    'Interest',
    'Bonus',
    'Tax Refund',
    'Gifts',
    'Other Income',
  ];

  // Initialize data
  Future<void> initializeData() async {
    await loadTransactions();
    await loadVirtualBanks();
    await loadBudgets();
    await loadEMIs();
    
    // Commented out sample data - uncomment if you want to test with sample data
    // if (_transactions.isEmpty && _virtualBanks.isEmpty) {
    //   print('FinanceProvider: No data found, adding sample data...');
    //   await _addSampleData();
    // }
    
    await calculateTotalBalance();
    await _loadCategoriesFromPreferences();
  }

  // Add sample data for testing
  Future<void> _addSampleData() async {
    try {
      // Add sample transactions
      final sampleTransactions = [
        Transaction(
          type: 'income',
          amount: 5000.0,
          category: 'Salary',
          description: 'Monthly Salary',
          date: DateTime.now().subtract(const Duration(days: 5)),
          isRecurring: true,
          recurringFrequency: 'monthly',
          nextDueDate: DateTime.now().add(const Duration(days: 25)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Transaction(
          type: 'expense',
          amount: 1200.0,
          category: 'Food & Dining',
          description: 'Grocery Shopping',
          date: DateTime.now().subtract(const Duration(days: 2)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Transaction(
          type: 'expense',
          amount: 800.0,
          category: 'Transportation',
          description: 'Monthly Bus Pass',
          date: DateTime.now().subtract(const Duration(days: 1)),
          isRecurring: true,
          recurringFrequency: 'monthly',
          nextDueDate: DateTime.now().add(const Duration(days: 29)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Transaction(
          type: 'income',
          amount: 2000.0,
          category: 'Freelance',
          description: 'Web Development Project',
          date: DateTime.now().subtract(const Duration(days: 3)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Transaction(
          type: 'expense',
          amount: 500.0,
          category: 'Bills & Utilities',
          description: 'Electricity Bill',
          date: DateTime.now().subtract(const Duration(days: 4)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (var transaction in sampleTransactions) {
        await _databaseHelper.insertTransaction(transaction);
      }

      // Add sample virtual bank
      final sampleBank = VirtualBank(
        id: 'vacation_fund',
        name: 'Vacation Fund',
        balance: 15000.0,
        targetAmount: 50000.0,
        color: '#4CAF50',
        icon: 'flight_takeoff',
        description: 'Saving for trip to Europe',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.insertVirtualBank(sampleBank);

      // Add sample budget
      final sampleBudget = Budget(
        category: 'Food & Dining',
        amount: 2000.0,
        spent: 1200.0,
        period: 'monthly',
        startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
        endDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.insertBudget(sampleBudget);

      // Reload all data
      await loadTransactions();
      await loadVirtualBanks();
      await loadBudgets();

      print('FinanceProvider: Sample data added successfully');
    } catch (e) {
      print('FinanceProvider: ERROR adding sample data: $e');
    }
  }

  // Transaction operations
  Future<void> addTransaction(Transaction transaction) async {
    print('FinanceProvider: Adding transaction - ${transaction.type}: ₹${transaction.amount}');
    
    await _databaseHelper.insertTransaction(transaction);
    
    print('FinanceProvider: Transaction inserted, now loading transactions...');
    await loadTransactions();
    
    print('FinanceProvider: Loaded ${_transactions.length} transactions, calculating balance...');
    await calculateTotalBalance();
    
    print('FinanceProvider: Updating budget spending...');
    await updateBudgetSpending(transaction);
    
    print('FinanceProvider: Notifying listeners...');
    notifyListeners();
    
    print('FinanceProvider: Transaction add process completed');
  }

  Future<void> loadTransactions() async {
    print('FinanceProvider: Loading transactions from database...');
    _transactions = await _databaseHelper.getTransactions();
    print('FinanceProvider: Loaded ${_transactions.length} transactions');
    
    // Debug: Print each transaction
    for (var transaction in _transactions) {
      print('Transaction: ${transaction.type} - ₹${transaction.amount} - ${transaction.description} - Active: ${transaction.isActive}');
    }
    
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _databaseHelper.updateTransaction(transaction);
    await loadTransactions();
    await calculateTotalBalance();
    notifyListeners();
  }

  Future<void> deleteTransaction(int id) async {
    await _databaseHelper.deleteTransaction(id);
    await loadTransactions();
    await calculateTotalBalance();
    notifyListeners();
  }

  // Virtual Bank operations
  Future<void> createVirtualBank({
    required String name,
    required double targetAmount,
    required String color,
    required String icon,
    String? description,
    bool enableAutoSave = false,
    double? autoSaveAmount,
    String? autoSaveFrequency,
    int? autoSaveDay,
    String? type,
    String? debitSource,
    DateTime? targetDate,
  }) async {
    final bank = VirtualBank(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      balance: 0.0,
      targetAmount: targetAmount,
      targetDate: targetDate,
      color: color,
      icon: icon,
      description: description ?? '',
      type: type ?? 'savings', // Provide default value
      debitSource: debitSource, // This can be null
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseHelper.insertVirtualBank(bank);
    await loadVirtualBanks();
  }

  Future<void> loadVirtualBanks() async {
    _virtualBanks = await _databaseHelper.getVirtualBanks();
    notifyListeners();
  }

  Future<void> transferToVirtualBank(String virtualBankId, double amount) async {
    final virtualBank = await _databaseHelper.getVirtualBank(virtualBankId);
    if (virtualBank != null) {
      final updatedBank = VirtualBank(
        id: virtualBank.id,
        name: virtualBank.name,
        balance: virtualBank.balance + amount,
        targetAmount: virtualBank.targetAmount,
        color: virtualBank.color,
        icon: virtualBank.icon,
        description: virtualBank.description,
        type: virtualBank.type,
        debitSource: virtualBank.debitSource,
        createdAt: virtualBank.createdAt,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateVirtualBank(updatedBank);

      // Create transfer transaction
      final transferTransaction = Transaction(
        type: 'transfer',
        amount: amount,
        category: 'Transfer',
        description: 'Transfer to ${virtualBank.name}',
        date: DateTime.now(),
        virtualBankId: virtualBankId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.insertTransaction(transferTransaction);
      await loadVirtualBanks();
      await loadTransactions();
      await calculateTotalBalance();
      notifyListeners();
    }
  }

  Future<void> withdrawFromVirtualBank(String virtualBankId, double amount) async {
    final virtualBank = await _databaseHelper.getVirtualBank(virtualBankId);
    if (virtualBank != null && virtualBank.balance >= amount) {
      final updatedBank = VirtualBank(
        id: virtualBank.id,
        name: virtualBank.name,
        balance: virtualBank.balance - amount,
        targetAmount: virtualBank.targetAmount,
        color: virtualBank.color,
        icon: virtualBank.icon,
        description: virtualBank.description,
        type: virtualBank.type,
        debitSource: virtualBank.debitSource,
        createdAt: virtualBank.createdAt,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateVirtualBank(updatedBank);

      // Create withdrawal transaction
      final withdrawalTransaction = Transaction(
        type: 'transfer',
        amount: amount,
        category: 'Transfer',
        description: 'Withdrawal from ${virtualBank.name}',
        date: DateTime.now(),
        virtualBankId: virtualBankId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.insertTransaction(withdrawalTransaction);
      await loadVirtualBanks();
      await loadTransactions();
      await calculateTotalBalance();
      notifyListeners();
    }
  }

  // Update virtual bank
  Future<void> updateVirtualBank(VirtualBank updatedBank) async {
    await _databaseHelper.updateVirtualBank(updatedBank);
    await loadVirtualBanks();
    notifyListeners();
  }

  // Delete virtual bank
  Future<void> deleteVirtualBank(String virtualBankId) async {
    // First check if there are any transactions linked to this virtual bank
    final linkedTransactions = _transactions.where((t) => t.virtualBankId == virtualBankId).toList();
    
    if (linkedTransactions.isNotEmpty) {
      throw Exception('Cannot delete virtual bank with linked transactions. Please remove or transfer linked transactions first.');
    }
    
    await _databaseHelper.deleteVirtualBank(virtualBankId);
    await loadVirtualBanks();
    notifyListeners();
  }

  // Budget operations
  Future<void> createBudget({
    required String category,
    required double amount,
    required String period,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final budget = Budget(
      category: category,
      amount: amount,
      period: period,
      startDate: startDate,
      endDate: endDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseHelper.insertBudget(budget);
    await loadBudgets();
    notifyListeners();
  }

  Future<void> loadBudgets() async {
    _budgets = await _databaseHelper.getBudgets(isActive: true);
    notifyListeners();
  }

  Future<void> updateBudgetSpending(Transaction transaction) async {
    if (transaction.type == 'expense') {
      for (var budget in _budgets) {
        if (budget.category == transaction.category &&
            transaction.date.isAfter(budget.startDate) &&
            transaction.date.isBefore(budget.endDate)) {
          final updatedBudget = Budget(
            id: budget.id,
            category: budget.category,
            amount: budget.amount,
            spent: budget.spent + transaction.amount,
            period: budget.period,
            startDate: budget.startDate,
            endDate: budget.endDate,
            createdAt: budget.createdAt,
            updatedAt: DateTime.now(),
          );

          await _databaseHelper.updateBudget(updatedBudget);
        }
      }
      await loadBudgets();
    }
  }

  // Analytics
  Future<Map<String, double>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _databaseHelper.getExpensesByCategory(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyTrends({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _databaseHelper.getMonthlyTrends(
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Get monthly transaction summary
  Map<String, dynamic> getMonthlyTransactionSummary([DateTime? month]) {
    final targetMonth = month ?? DateTime.now();
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);
    
    final monthTransactions = _transactions.where((t) => 
      t.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
      t.date.isBefore(endOfMonth.add(const Duration(days: 1)))).toList();
    
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    
    for (var transaction in monthTransactions) {
      if (transaction.type == 'income' || 
          (transaction.type == 'recurring' && _isIncomeCategory(transaction.category))) {
        totalIncome += transaction.amount;
      } else if (transaction.type == 'expense' || 
                 (transaction.type == 'recurring' && !_isIncomeCategory(transaction.category))) {
        totalExpenses += transaction.amount;
      }
    }
    
    return {
      'month': targetMonth,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'netAmount': totalIncome - totalExpenses,
      'transactionCount': monthTransactions.length,
      'transactions': monthTransactions,
    };
  }

  // Helper method to check if a category is income-related
  bool _isIncomeCategory(String category) {
    return incomeCategories.contains(category);
  }

  Future<void> calculateTotalBalance() async {
    // Calculate total income and expenses from transactions
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    
    for (var transaction in _transactions) {
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
      } else if (transaction.type == 'expense') {
        totalExpenses += transaction.amount;
      } else if (transaction.type == 'recurring') {
        // Recurring transactions should be treated based on their category
        if (transaction.category == 'Salary' || 
            transaction.category == 'Freelance' || 
            transaction.category == 'Business' || 
            transaction.category == 'Investments' ||
            transaction.category == 'Rental Income' ||
            transaction.category == 'Dividends' ||
            transaction.category == 'Interest' ||
            transaction.category == 'Bonus' ||
            transaction.category == 'Tax Refund' ||
            transaction.category == 'Gifts' ||
            transaction.category == 'Other Income') {
          // It's recurring income
          totalIncome += transaction.amount;
        } else {
          // It's recurring expense
          totalExpenses += transaction.amount;
        }
      }
      // Skip transfer transactions as they're internal movements
    }
    
    // Total balance = Income - Expenses
    _totalBalance = totalIncome - totalExpenses;
    
    // Subtract virtual bank balances from main balance (as they're allocated funds)
    double virtualBankTotal = 0.0;
    for (var bank in _virtualBanks) {
      virtualBankTotal += bank.balance;
    }
    
    // Don't subtract virtual banks from total, they're part of total assets
    // _totalBalance -= virtualBankTotal; // Removed this line
    
    print('Total Income: ₹$totalIncome');
    print('Total Expenses: ₹$totalExpenses'); 
    print('Virtual Banks Total: ₹$virtualBankTotal');
    print('Final Balance: ₹$_totalBalance');
    
    // Update provider properties
    _totalIncome = totalIncome;
    _totalExpenses = totalExpenses;
    
    notifyListeners();
  }

  // Recurring transactions
  Future<void> processRecurringTransactions() async {
    final now = DateTime.now();
    final recurringTransactions = await _databaseHelper.getTransactions(
      type: 'recurring',
    );

    for (var transaction in recurringTransactions) {
      if (transaction.nextDueDate != null &&
          transaction.nextDueDate!.isBefore(now) &&
          transaction.isActive) {
        
        // Handle auto-save transactions (transfers to virtual banks)
        if (transaction.category == 'Auto-Save' && transaction.virtualBankId != null) {
          // Check if user has sufficient balance for auto-save
          if (_totalBalance >= transaction.amount) {
            // Transfer to virtual bank
            await transferToVirtualBank(transaction.virtualBankId!, transaction.amount);
            
            print('FinanceProvider: Auto-save executed - ₹${transaction.amount} transferred to virtual bank');
          } else {
            print('FinanceProvider: Auto-save skipped - insufficient balance (₹${_totalBalance} < ₹${transaction.amount})');
            // TODO: Could send notification to user about insufficient funds
          }
        } else {
          // Handle regular recurring transactions
          final actualTransaction = Transaction(
            type: transaction.category == 'Salary' || 
                 transaction.category == 'Freelance' || 
                 transaction.category == 'Business' || 
                 transaction.category == 'Investments' ||
                 transaction.category == 'Rental Income' ||
                 transaction.category == 'Dividends' ||
                 transaction.category == 'Interest' ||
                 transaction.category == 'Bonus' ||
                 transaction.category == 'Tax Refund' ||
                 transaction.category == 'Gifts' ||
                 transaction.category == 'Other Income' ? 'income' : 'expense',
            amount: transaction.amount,
            category: transaction.category,
            description: '${transaction.description} (Recurring)',
            date: now,
            virtualBankId: transaction.virtualBankId,
            createdAt: now,
            updatedAt: now,
          );

          await _databaseHelper.insertTransaction(actualTransaction);

          // Process virtual bank withdrawal if needed for expenses
          if (actualTransaction.type == 'expense' && transaction.virtualBankId != null) {
            await withdrawFromVirtualBank(transaction.virtualBankId!, transaction.amount);
          }
        }

        // Update next due date
        DateTime nextDue;
        switch (transaction.recurringFrequency) {
          case 'monthly':
            // Handle monthly scheduling with proper day handling
            final currentDay = transaction.nextDueDate!.day;
            DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
            int lastDayOfNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
            int targetDay = currentDay > lastDayOfNextMonth ? lastDayOfNextMonth : currentDay;
            nextDue = DateTime(nextMonth.year, nextMonth.month, targetDay);
            break;
          case 'weekly':
            nextDue = transaction.nextDueDate!.add(const Duration(days: 7));
            break;
          case 'yearly':
            nextDue = DateTime(transaction.nextDueDate!.year + 1, transaction.nextDueDate!.month, transaction.nextDueDate!.day);
            break;
          default:
            nextDue = DateTime(now.year, now.month + 1, now.day);
        }

        final updatedRecurring = transaction.copyWith(
          nextDueDate: nextDue,
          updatedAt: now,
        );

        await _databaseHelper.updateTransaction(updatedRecurring);
      }
    }

    await loadTransactions();
    await loadVirtualBanks();
    await calculateTotalBalance();
    notifyListeners();
  }

  // Financial insights
  Map<String, dynamic> getFinancialInsights() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    final thisMonthExpenses = _transactions
        .where((t) => t.type == 'expense' && t.date.isAfter(thisMonth))
        .fold(0.0, (sum, t) => sum + t.amount);

    final lastMonthExpenses = _transactions
        .where((t) => t.type == 'expense' && 
              t.date.isAfter(lastMonth) && 
              t.date.isBefore(thisMonth))
        .fold(0.0, (sum, t) => sum + t.amount);

    final expenseChange = thisMonthExpenses - lastMonthExpenses;
    final changePercentage = lastMonthExpenses > 0 
        ? (expenseChange / lastMonthExpenses) * 100 
        : 0.0;

    return {
      'thisMonthExpenses': thisMonthExpenses,
      'lastMonthExpenses': lastMonthExpenses,
      'expenseChange': expenseChange,
      'changePercentage': changePercentage,
      'insights': _generateInsights(thisMonthExpenses, lastMonthExpenses, changePercentage),
    };
  }

  List<String> _generateInsights(double thisMonth, double lastMonth, double changePercentage) {
    List<String> insights = [];

    if (changePercentage > 20) {
      insights.add('Your spending increased by ${changePercentage.toStringAsFixed(1)}% this month. Consider reviewing your expenses.');
    } else if (changePercentage < -20) {
      insights.add('Great job! You reduced spending by ${changePercentage.abs().toStringAsFixed(1)}% this month.');
    }

    // Check budget performance
    for (var budget in _budgets) {
      if (budget.isOverBudget) {
        insights.add('You\'re over budget in ${budget.category} by \$${(budget.spent - budget.amount).toStringAsFixed(2)}');
      } else if (budget.progressPercentage > 0.8) {
        insights.add('You\'re close to your ${budget.category} budget limit (${(budget.progressPercentage * 100).toStringAsFixed(0)}% used)');
      }
    }

    // Virtual bank insights
    for (var bank in _virtualBanks) {
      if (bank.progressPercentage >= 1.0) {
        insights.add('🎉 Congratulations! You\'ve reached your ${bank.name} savings goal!');
      } else if (bank.progressPercentage > 0.8) {
        insights.add('You\'re ${(bank.progressPercentage * 100).toStringAsFixed(0)}% towards your ${bank.name} goal!');
      }
    }

    return insights;
  }

  // Dynamic category management
  void addExpenseCategory(String category) {
    if (!expenseCategories.contains(category)) {
      expenseCategories.add(category);
      _saveCategoriesToPreferences();
      notifyListeners();
    }
  }

  void addIncomeCategory(String category) {
    if (!incomeCategories.contains(category)) {
      incomeCategories.add(category);
      _saveCategoriesToPreferences();
      notifyListeners();
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    print('FinanceProvider: Clearing all data...');
    
    try {
      // Clear data from database
      await _databaseHelper.clearAllData();
      
      // Reset provider state
      _transactions = [];
      _virtualBanks = [];
      _budgets = [];
      _emis = [];
      _totalBalance = 0.0;
      _totalIncome = 0.0;
      _totalExpenses = 0.0;
      
      // Notify listeners to refresh UI
      notifyListeners();
      
      print('FinanceProvider: All data cleared successfully');
    } catch (e) {
      print('FinanceProvider: ERROR clearing data: $e');
      rethrow;
    }
  }

  // EMI operations
  Future<void> createEMI({
    required String name,
    required String lenderName,
    required double principalAmount,
    required double interestRate,
    required int tenureMonths,
    required DateTime startDate,
    required String category,
    String? description,
    String? virtualBankId,
    bool autoDebit = false,
    int? autoDebitDay,
  }) async {
    final emiId = _uuid.v4();
    
    // Calculate EMI details
    final monthlyEMI = EMI.calculateEMI(principalAmount, interestRate, tenureMonths);
    final totalAmount = monthlyEMI * tenureMonths;
    final totalInterest = totalAmount - principalAmount;
    
    // Calculate first due date
    DateTime firstDueDate;
    if (autoDebit && autoDebitDay != null) {
      // Set first due date to the specified day of next month
      final nextMonth = DateTime(startDate.year, startDate.month + 1, 1);
      final lastDayOfNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      final targetDay = autoDebitDay > lastDayOfNextMonth ? lastDayOfNextMonth : autoDebitDay;
      firstDueDate = DateTime(nextMonth.year, nextMonth.month, targetDay);
    } else {
      // Default to one month from start date
      firstDueDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
    }
    
    final emi = EMI(
      id: emiId,
      name: name,
      lenderName: lenderName,
      principalAmount: principalAmount,
      interestRate: interestRate,
      tenureMonths: tenureMonths,
      monthlyEMI: monthlyEMI,
      totalAmount: totalAmount,
      totalInterest: totalInterest,
      startDate: startDate,
      nextDueDate: firstDueDate,
      category: category,
      description: description,
      virtualBankId: virtualBankId,
      autoDebit: autoDebit,
      autoDebitDay: autoDebitDay,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseHelper.insertEMI(emi);
    
    // If auto-debit is enabled, create a recurring transaction
    if (autoDebit && autoDebitDay != null) {
      final autoDebitTransaction = Transaction(
        type: 'recurring',
        amount: monthlyEMI,
        category: 'EMI Payment',
        description: 'Auto EMI payment for $name',
        date: DateTime.now(),
        virtualBankId: virtualBankId,
        isRecurring: true,
        recurringFrequency: 'monthly',
        nextDueDate: firstDueDate,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _databaseHelper.insertTransaction(autoDebitTransaction);
      print('FinanceProvider: Created auto-debit recurring transaction for EMI: $name');
    }
    
    await loadEMIs();
    await loadTransactions();
    notifyListeners();
  }

  Future<void> loadEMIs() async {
    _emis = await _databaseHelper.getEMIs(isActive: true);
    notifyListeners();
  }

  Future<void> payEMIInstallment(String emiId, {double? customAmount, String? virtualBankId}) async {
    final emi = await _databaseHelper.getEMI(emiId);
    if (emi == null || emi.isCompleted) return;
    
    final paymentAmount = customAmount ?? emi.monthlyEMI;
    
    // Update EMI payment details
    await _databaseHelper.payEMIInstallment(emiId, paymentAmount);
    
    // Create payment transaction
    final paymentTransaction = Transaction(
      type: 'expense',
      amount: paymentAmount,
      category: 'EMI Payment',
      description: 'EMI payment for ${emi.name} - Installment ${emi.paidInstallments + 1}',
      date: DateTime.now(),
      virtualBankId: virtualBankId ?? emi.virtualBankId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await _databaseHelper.insertTransaction(paymentTransaction);
    
    // If paid from virtual bank, withdraw the amount
    if (virtualBankId != null || emi.virtualBankId != null) {
      final bankId = virtualBankId ?? emi.virtualBankId!;
      await withdrawFromVirtualBank(bankId, paymentAmount);
    }
    
    await loadEMIs();
    await loadTransactions();
    await calculateTotalBalance();
    notifyListeners();
  }

  Future<void> updateEMI(EMI updatedEMI) async {
    await _databaseHelper.updateEMI(updatedEMI);
    await loadEMIs();
    notifyListeners();
  }

  Future<void> deleteEMI(String emiId) async {
    // Check if there are any transactions linked to this EMI
    final linkedTransactions = _transactions.where((t) => 
      t.description.contains('EMI payment') && 
      t.description.contains(_emis.firstWhere((e) => e.id == emiId, orElse: () => 
        EMI(id: '', name: '', lenderName: '', principalAmount: 0, interestRate: 0, 
             tenureMonths: 0, monthlyEMI: 0, totalAmount: 0, totalInterest: 0, 
             startDate: DateTime.now(), category: '', createdAt: DateTime.now(), 
             updatedAt: DateTime.now())).name)
    ).toList();
    
    if (linkedTransactions.isNotEmpty) {
      throw Exception('Cannot delete EMI with payment history. Please archive it instead.');
    }
    
    await _databaseHelper.deleteEMI(emiId);
    await loadEMIs();
    notifyListeners();
  }

  // Process auto-debit EMI payments
  Future<void> processEMIAutoDebits() async {
    final now = DateTime.now();
    
    for (var emi in _emis) {
      if (emi.autoDebit && 
          emi.nextDueDate != null && 
          emi.nextDueDate!.isBefore(now) && 
          !emi.isCompleted) {
        
        // Check if sufficient balance is available
        bool canPay = false;
        if (emi.virtualBankId != null) {
          final virtualBank = await _databaseHelper.getVirtualBank(emi.virtualBankId!);
          canPay = virtualBank != null && virtualBank.balance >= emi.monthlyEMI;
        } else {
          canPay = _totalBalance >= emi.monthlyEMI;
        }
        
        if (canPay) {
          await payEMIInstallment(emi.id, virtualBankId: emi.virtualBankId);
          print('FinanceProvider: Auto-debit EMI payment executed for ${emi.name}: ₹${emi.monthlyEMI}');
        } else {
          print('FinanceProvider: Auto-debit EMI payment skipped for ${emi.name} - insufficient balance');
          // TODO: Could send notification to user about insufficient funds
        }
      }
    }
  }

  // Get EMI insights
  Map<String, dynamic> getEMIInsights() {
    if (_emis.isEmpty) {
      return {
        'totalMonthlyEMI': 0.0,
        'totalRemainingAmount': 0.0,
        'totalInterestSaved': 0.0,
        'upcomingPayments': <EMI>[],
        'completedEMIs': 0,
      };
    }
    
    double totalMonthlyEMI = 0.0;
    double totalRemainingAmount = 0.0;
    double totalInterestSaved = 0.0;
    List<EMI> upcomingPayments = [];
    int completedEMIs = 0;
    
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    
    for (var emi in _emis) {
      if (!emi.isCompleted) {
        totalMonthlyEMI += emi.monthlyEMI;
        totalRemainingAmount += emi.remainingAmount;
        
        if (emi.nextDueDate != null && emi.nextDueDate!.isBefore(nextWeek)) {
          upcomingPayments.add(emi);
        }
      } else {
        completedEMIs++;
        // Calculate interest saved if any (for early payments)
        if (emi.paidAmount < emi.totalAmount) {
          totalInterestSaved += (emi.totalAmount - emi.paidAmount);
        }
      }
    }
    
    // Sort upcoming payments by due date
    upcomingPayments.sort((a, b) => a.nextDueDate!.compareTo(b.nextDueDate!));
    
    return {
      'totalMonthlyEMI': totalMonthlyEMI,
      'totalRemainingAmount': totalRemainingAmount,
      'totalInterestSaved': totalInterestSaved,
      'upcomingPayments': upcomingPayments,
      'completedEMIs': completedEMIs,
      'activeEMIs': _emis.where((e) => !e.isCompleted).length,
    };
  }

  Future<void> _loadCategoriesFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final expenseCategoriesJson = prefs.getString('expense_categories');
    if (expenseCategoriesJson != null) {
      final List<dynamic> expenseList = jsonDecode(expenseCategoriesJson);
      expenseCategories = expenseList.cast<String>();
    }
    
    final incomeCategoriesJson = prefs.getString('income_categories');
    if (incomeCategoriesJson != null) {
      final List<dynamic> incomeList = jsonDecode(incomeCategoriesJson);
      incomeCategories = incomeList.cast<String>();
    }
  }

  Future<void> _saveCategoriesToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('expense_categories', jsonEncode(expenseCategories));
    await prefs.setString('income_categories', jsonEncode(incomeCategories));
  }
}