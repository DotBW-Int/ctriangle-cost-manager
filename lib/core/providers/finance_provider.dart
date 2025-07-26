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

  // Add a private variable to track the next transaction number
  int _nextTransactionNumber = 1;

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
    
    // Initialize transaction numbering
    await _initializeTransactionNumbering();
    
    await calculateTotalBalance();
    await _loadCategoriesFromPreferences();
  }

  // Initialize transaction numbering system
  Future<void> _initializeTransactionNumbering() async {
    // Find the highest existing transaction number
    int maxNumber = 0;
    for (var transaction in _transactions) {
      if (transaction.transactionNumber != null && transaction.transactionNumber! > maxNumber) {
        maxNumber = transaction.transactionNumber!;
      }
    }
    
    // Set next number to be one higher than the maximum
    _nextTransactionNumber = maxNumber + 1;
    
    // Update existing transactions without numbers
    List<Transaction> transactionsToUpdate = _transactions
        .where((t) => t.transactionNumber == null)
        .toList();
    
    for (var transaction in transactionsToUpdate) {
      final updatedTransaction = transaction.copyWith(
        transactionNumber: _nextTransactionNumber++,
        updatedAt: DateTime.now(),
      );
      await _databaseHelper.updateTransaction(updatedTransaction);
    }
    
    // Reload transactions to get updated numbers
    if (transactionsToUpdate.isNotEmpty) {
      await loadTransactions();
    }
  }

  // Generate next transaction number
  int _generateTransactionNumber() {
    return _nextTransactionNumber++;
  }

  // Helper method to update virtual bank balance
  Future<void> _updateVirtualBankBalance(String virtualBankId, double amount, String transactionType) async {
    final virtualBank = await _databaseHelper.getVirtualBank(virtualBankId);
    if (virtualBank != null) {
      double newBalance = virtualBank.balance;
      
      // Update balance based on transaction type
      if (transactionType == 'income') {
        newBalance += amount;
      } else if (transactionType == 'expense') {
        newBalance -= amount;
      }
      
      final updatedBank = VirtualBank(
        id: virtualBank.id,
        name: virtualBank.name,
        balance: newBalance,
        targetAmount: virtualBank.targetAmount,
        targetDate: virtualBank.targetDate,
        color: virtualBank.color,
        icon: virtualBank.icon,
        description: virtualBank.description,
        type: virtualBank.type,
        debitSource: virtualBank.debitSource,
        createdAt: virtualBank.createdAt,
        updatedAt: DateTime.now(),
      );

      await _databaseHelper.updateVirtualBank(updatedBank);
      await loadVirtualBanks();
    }
  }

  // Transaction operations
  Future<void> addTransaction(Transaction transaction) async {
    // Assign transaction number if not already set
    final transactionWithNumber = transaction.transactionNumber == null 
        ? transaction.copyWith(transactionNumber: _generateTransactionNumber())
        : transaction;
    
    await _databaseHelper.insertTransaction(transactionWithNumber);
    await loadTransactions();
    
    // Only update virtual bank balance for expense transactions from virtual banks
    // Income transactions should not automatically affect virtual bank balances
    if (transactionWithNumber.virtualBankId != null && transactionWithNumber.type == 'expense') {
      await withdrawFromVirtualBank(transactionWithNumber.virtualBankId!, transactionWithNumber.amount);
    }
    
    // Recalculate total balance after adding transaction
    await calculateTotalBalance();
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    _transactions = await _databaseHelper.getTransactions();
    notifyListeners();
  }

  // Anti-tampering transaction update system
  Future<void> updateTransaction(Transaction transaction) async {
    final originalTransaction = _transactions.firstWhere((t) => t.id == transaction.id);
    
    // Create edit history entry with detailed change tracking
    List<Map<String, dynamic>> editHistory = [];
    if (originalTransaction.editHistory != null) {
      editHistory = List<Map<String, dynamic>>.from(originalTransaction.editHistory!);
    }
    
    // Track detailed changes for audit trail
    Map<String, dynamic> changes = {};
    bool hasSignificantChanges = false;
    
    if (originalTransaction.amount != transaction.amount) {
      changes['amount'] = {
        'from': originalTransaction.amount,
        'to': transaction.amount,
        'impact': _calculateAmountImpact(originalTransaction, transaction),
      };
      hasSignificantChanges = true;
    }
    
    if (originalTransaction.type != transaction.type) {
      changes['type'] = {
        'from': originalTransaction.type,
        'to': transaction.type,
        'requires_reversal': true,
      };
      hasSignificantChanges = true;
    }
    
    if (originalTransaction.category != transaction.category) {
      changes['category'] = {
        'from': originalTransaction.category,
        'to': transaction.category,
      };
      hasSignificantChanges = true;
    }
    
    if (originalTransaction.description != transaction.description) {
      changes['description'] = {
        'from': originalTransaction.description,
        'to': transaction.description,
      };
    }
    
    if (originalTransaction.date != transaction.date) {
      changes['date'] = {
        'from': originalTransaction.date.toIso8601String(),
        'to': transaction.date.toIso8601String(),
      };
    }
    
    if (originalTransaction.virtualBankId != transaction.virtualBankId) {
      changes['virtual_bank_id'] = {
        'from': originalTransaction.virtualBankId,
        'to': transaction.virtualBankId,
        'requires_bank_adjustment': true,
      };
      hasSignificantChanges = true;
    }
    
    // If there are significant changes, create immutable audit trail
    if (hasSignificantChanges) {
      await _handleSignificantTransactionEdit(originalTransaction, transaction, changes);
    } else {
      // For minor edits (description, date only), update in place
      await _handleMinorTransactionEdit(originalTransaction, transaction, changes);
    }
    
    await loadTransactions();
    await calculateTotalBalance();
    notifyListeners();
  }

  // Handle significant edits that affect balance/type/amount
  Future<void> _handleSignificantTransactionEdit(
    Transaction originalTransaction, 
    Transaction newTransaction, 
    Map<String, dynamic> changes
  ) async {
    print('FinanceProvider: Processing significant transaction edit with step-by-step reversal');
    
    final newTransactionNumber = _generateTransactionNumber();
    print('FinanceProvider: Generated new transaction number: $newTransactionNumber');
    
    // Step 1: Create audit record of the original transaction
    final auditTransaction = originalTransaction.copyWith(
      isActive: false, // Mark original as inactive
      editHistory: [
        ...?originalTransaction.editHistory,
        {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'action': 'archived_for_edit',
          'changes': changes,
          'new_transaction_number': newTransactionNumber, // Use transaction number for reference
        }
      ],
      updatedAt: DateTime.now(),
    );
    
    // Step 2: Carefully reverse the financial impact of original transaction
    await _reverseTransactionImpact(originalTransaction);
    
    // Step 3: Update the original to archived status
    await _databaseHelper.updateTransaction(auditTransaction);
    
    // Step 4: Create completely new transaction with fresh data
    final now = DateTime.now();
    final editedTransaction = Transaction(
      // Explicitly set to null to force new ID generation
      id: null,
      transactionNumber: newTransactionNumber,
      type: newTransaction.type,
      amount: newTransaction.amount,
      category: newTransaction.category,
      description: newTransaction.description,
      date: newTransaction.date,
      receiptPath: newTransaction.receiptPath,
      virtualBankId: newTransaction.virtualBankId,
      isRecurring: newTransaction.isRecurring,
      recurringFrequency: newTransaction.recurringFrequency,
      nextDueDate: newTransaction.nextDueDate,
      isActive: true,
      originalTransactionId: originalTransaction.id, // Link to original
      editHistory: [
        {
          'timestamp': now.millisecondsSinceEpoch,
          'action': 'created_from_edit',
          'original_transaction_id': originalTransaction.id,
          'original_transaction_number': originalTransaction.transactionNumber,
          'changes': changes,
        }
      ],
      createdAt: now,
      updatedAt: now,
    );
    
    // Step 5: Insert the completely new transaction directly to database
    // This ensures a fresh ID is generated and no existing record is overwritten
    await _databaseHelper.insertTransaction(editedTransaction);
    
    // Step 6: Apply new financial impact if needed
    if (editedTransaction.virtualBankId != null && editedTransaction.type == 'expense') {
      await _updateVirtualBankBalance(editedTransaction.virtualBankId!, editedTransaction.amount, editedTransaction.type);
    }
    
    print('FinanceProvider: Created new transaction with number $newTransactionNumber, original archived as inactive');
    print('FinanceProvider: Transaction edit completed with full audit trail');
  }

  // Handle minor edits (description, date only)
  Future<void> _handleMinorTransactionEdit(
    Transaction originalTransaction, 
    Transaction newTransaction, 
    Map<String, dynamic> changes
  ) async {
    final editHistory = [
      ...?originalTransaction.editHistory,
      {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'action': 'minor_edit',
        'changes': changes,
      }
    ];
    
    final updatedTransaction = newTransaction.copyWith(
      editHistory: editHistory,
      updatedAt: DateTime.now(),
    );
    
    await _databaseHelper.updateTransaction(updatedTransaction);
  }

  // Carefully reverse transaction impact step by step
  Future<void> _reverseTransactionImpact(Transaction transaction) async {
    print('FinanceProvider: Reversing impact of transaction ${transaction.transactionNumber}');
    
    // Step 1: Handle virtual bank impact reversal
    if (transaction.virtualBankId != null) {
      await _reverseVirtualBankImpact(transaction);
    }
    
    // Step 2: The balance calculation will be handled when we reload transactions
    // since we're marking the original as inactive and creating a new one
    
    print('FinanceProvider: Transaction impact reversal completed');
  }

  // Reverse virtual bank impact based on transaction type
  Future<void> _reverseVirtualBankImpact(Transaction transaction) async {
    final virtualBank = await _databaseHelper.getVirtualBank(transaction.virtualBankId!);
    if (virtualBank == null) return;
    
    double balanceAdjustment = 0.0;
    
    // Determine reversal amount based on original transaction type
    if (transaction.type == 'expense') {
      // Original was expense (debit), so add back to virtual bank
      balanceAdjustment = transaction.amount;
      print('FinanceProvider: Reversing expense - adding ₹${transaction.amount} back to ${virtualBank.name}');
    } else if (transaction.type == 'income') {
      // Original was income (credit), so deduct from virtual bank
      balanceAdjustment = -transaction.amount;
      print('FinanceProvider: Reversing income - deducting ₹${transaction.amount} from ${virtualBank.name}');
    } else if (transaction.type == 'transfer') {
      // Handle transfer reversal
      balanceAdjustment = -transaction.amount;
      print('FinanceProvider: Reversing transfer - deducting ₹${transaction.amount} from ${virtualBank.name}');
    }
    
    // Apply the reversal
    if (balanceAdjustment != 0.0) {
      final updatedBank = virtualBank.copyWith(
        balance: virtualBank.balance + balanceAdjustment,
        updatedAt: DateTime.now(),
      );
      
      await _databaseHelper.updateVirtualBank(updatedBank);
      print('FinanceProvider: Virtual bank ${virtualBank.name} balance updated: ₹${virtualBank.balance} → ₹${updatedBank.balance}');
    }
  }

  // Calculate the impact of amount changes
  Map<String, dynamic> _calculateAmountImpact(Transaction original, Transaction updated) {
    final difference = updated.amount - original.amount;
    
    String impactType;
    if (original.type == 'expense' && updated.type == 'expense') {
      impactType = difference > 0 ? 'increased_expense' : 'decreased_expense';
    } else if (original.type == 'income' && updated.type == 'income') {
      impactType = difference > 0 ? 'increased_income' : 'decreased_income';
    } else {
      impactType = 'type_changed';
    }
    
    return {
      'difference': difference,
      'impact_type': impactType,
      'affects_balance': true,
    };
  }

  // Get transaction audit trail
  Future<List<Transaction>> getTransactionAuditTrail(int transactionId) async {
    final allTransactions = await _databaseHelper.getTransactions(includeInactive: true);
    
    // Find the main transaction
    final mainTransaction = allTransactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => throw Exception('Transaction not found'),
    );
    
    List<Transaction> auditTrail = [mainTransaction];
    
    // Find all related transactions (edits, originals)
    if (mainTransaction.originalTransactionId != null) {
      // This is an edited transaction, find the original
      final original = allTransactions.firstWhere(
        (t) => t.id == mainTransaction.originalTransactionId,
        orElse: () => throw Exception('Original transaction not found'),
      );
      auditTrail.insert(0, original);
    }
    
    // Find all edits of this transaction
    final edits = allTransactions.where(
      (t) => t.originalTransactionId == transactionId,
    ).toList();
    
    auditTrail.addAll(edits);
    
    // Sort by creation date
    auditTrail.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    return auditTrail;
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
    _budgets = await _databaseHelper.getBudgets();
    for (var budget in _budgets) {
      await updateBudgetSpending(null, budget: budget);
    }
    notifyListeners();
  }

  Future<void> updateBudget(Budget budget) async {
    await _databaseHelper.updateBudget(budget);
    await loadBudgets();
    notifyListeners();
  }

  Future<void> deleteBudget(int id) async {
    await _databaseHelper.deleteBudget(id);
    await loadBudgets();
    notifyListeners();
  }

  Future<void> updateBudgetSpending(String? category, {Budget? budget}) async {
    final budgetToUpdate = budget ?? _budgets.firstWhere((b) => b.category == category);
    
    final spent = _transactions
        .where((t) => t.category == budgetToUpdate.category && 
                     t.type == 'expense' && 
                     t.isActive)
        .fold(0.0, (sum, t) => sum + t.amount);
    
    final updatedBudget = budgetToUpdate.copyWith(
      spent: spent,
      updatedAt: DateTime.now(),
    );
    await _databaseHelper.updateBudget(updatedBudget);
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
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    
    print('FinanceProvider: calculateTotalBalance - Processing ${_transactions.length} total transactions');
    
    for (var transaction in _transactions) {
      print('FinanceProvider: Transaction ${transaction.id} - Type: ${transaction.type}, Amount: ${transaction.amount}, Active: ${transaction.isActive}');
      
      if (!transaction.isActive) {
        print('FinanceProvider: Skipping inactive transaction ${transaction.id}');
        continue;
      }
      
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
        print('FinanceProvider: Added ₹${transaction.amount} to income (Total: ₹$totalIncome)');
      } else if (transaction.type == 'expense') {
        totalExpenses += transaction.amount;
        print('FinanceProvider: Added ₹${transaction.amount} to expenses (Total: ₹$totalExpenses)');
      } else if (transaction.type == 'recurring') {
        // Handle recurring transactions based on category
        if (_isIncomeCategory(transaction.category)) {
          totalIncome += transaction.amount;
          print('FinanceProvider: Added recurring ₹${transaction.amount} to income (Category: ${transaction.category})');
        } else {
          totalExpenses += transaction.amount;
          print('FinanceProvider: Added recurring ₹${transaction.amount} to expenses (Category: ${transaction.category})');
        }
      }
      // Skip transfer transactions as they're internal movements
    }
    
    // Total balance = Income - Expenses
    _totalBalance = totalIncome - totalExpenses;
    
    // Update provider properties
    _totalIncome = totalIncome;
    _totalExpenses = totalExpenses;
    
    print('FinanceProvider: Final totals - Income: ₹$totalIncome, Expenses: ₹$totalExpenses, Balance: ₹$_totalBalance');
    
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

  // Delete/Revert transaction (marks as inactive for audit trail)
  Future<void> deleteTransaction(int transactionId) async {
    print('FinanceProvider: Deleting/reverting transaction $transactionId');
    
    try {
      final transaction = _transactions.firstWhere((t) => t.id == transactionId);
      
      // Step 1: Reverse the financial impact of the transaction
      await _reverseTransactionImpact(transaction);
      
      // Step 2: Mark transaction as inactive (soft delete for audit trail)
      final deletedTransaction = transaction.copyWith(
        isActive: false,
        editHistory: [
          ...?transaction.editHistory,
          {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'action': 'deleted',
            'reason': 'user_requested_deletion',
          }
        ],
        updatedAt: DateTime.now(),
      );
      
      // Step 3: Update in database
      await _databaseHelper.updateTransaction(deletedTransaction);
      
      // Step 4: Reload data and recalculate balances
      await loadTransactions();
      await loadVirtualBanks();
      await calculateTotalBalance();
      notifyListeners();
      
      print('FinanceProvider: Transaction $transactionId successfully deleted/reverted');
    } catch (e) {
      print('FinanceProvider: ERROR deleting transaction $transactionId: $e');
      rethrow;
    }
  }

  // Virtual Bank operations
  Future<void> createVirtualBank({
    required String name,
    required double targetAmount,
    required String color,
    required String icon,
    required String description,
    String type = 'savings',
    String debitSource = 'bank_account',
    DateTime? targetDate,
    bool enableAutoSave = false,
    double? autoSaveAmount,
    String? autoSaveFrequency,
    int? autoSaveDay,
  }) async {
    final virtualBankId = _uuid.v4();
    
    final virtualBank = VirtualBank(
      id: virtualBankId,
      name: name,
      balance: 0.0,
      targetAmount: targetAmount,
      targetDate: targetDate,
      color: color,
      icon: icon,
      description: description,
      type: type,
      debitSource: debitSource,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _databaseHelper.insertVirtualBank(virtualBank);
    
    // If auto-save is enabled, create a recurring transaction
    if (enableAutoSave && autoSaveAmount != null && autoSaveFrequency != null && autoSaveDay != null) {
      DateTime nextAutoSaveDate;
      
      if (autoSaveFrequency == 'weekly') {
        // Calculate next occurrence of the specified weekday
        final now = DateTime.now();
        final daysUntilTarget = (autoSaveDay - now.weekday) % 7;
        nextAutoSaveDate = now.add(Duration(days: daysUntilTarget == 0 ? 7 : daysUntilTarget));
      } else { // monthly
        // Calculate next occurrence of the specified day of month
        final now = DateTime.now();
        final targetMonth = autoSaveDay <= now.day ? now.month + 1 : now.month;
        final targetYear = targetMonth > 12 ? now.year + 1 : now.year;
        final adjustedMonth = targetMonth > 12 ? 1 : targetMonth;
        
        // Handle end-of-month cases
        final lastDayOfTargetMonth = DateTime(targetYear, adjustedMonth + 1, 0).day;
        final adjustedDay = autoSaveDay > lastDayOfTargetMonth ? lastDayOfTargetMonth : autoSaveDay;
        
        nextAutoSaveDate = DateTime(targetYear, adjustedMonth, adjustedDay);
      }
      
      final autoSaveTransaction = Transaction(
        type: 'recurring',
        amount: autoSaveAmount,
        category: 'Auto-Save',
        description: 'Auto-save to ${name}',
        date: DateTime.now(),
        virtualBankId: virtualBankId,
        isRecurring: true,
        recurringFrequency: autoSaveFrequency,
        nextDueDate: nextAutoSaveDate,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _databaseHelper.insertTransaction(autoSaveTransaction);
    }
    
    await loadVirtualBanks();
    await loadTransactions();
    notifyListeners();
    
    print('FinanceProvider: Virtual bank "${name}" created successfully with ID: $virtualBankId');
  }
}