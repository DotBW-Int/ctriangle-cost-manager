import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert'; // Add this import for jsonEncode
import '../models/models.dart' as models;

// Add web-specific imports
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  static const String _databaseName = 'cost_manager.db';
  static const int _databaseVersion = 4; // Increment for anti-tampering support

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      // Initialize web database factory if on web
      if (kIsWeb) {
        databaseFactory = databaseFactoryFfiWeb;
      }
      
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _databaseName);

      print('DatabaseHelper: Opening database at: $path');
      print('DatabaseHelper: Database version: $_databaseVersion');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          print('DatabaseHelper: Database opened successfully');
          
          // Check if transaction_number column exists and add if missing
          var tableInfo = await db.rawQuery("PRAGMA table_info(transactions)");
          bool hasTransactionNumber = tableInfo.any((column) => column['name'] == 'transaction_number');
          
          if (!hasTransactionNumber) {
            print('DatabaseHelper: Adding missing transaction_number column');
            try {
              await db.execute('ALTER TABLE transactions ADD COLUMN transaction_number INTEGER');
              print('DatabaseHelper: transaction_number column added successfully');
            } catch (e) {
              print('DatabaseHelper: Error adding transaction_number column: $e');
            }
          }
        },
        readOnly: false,
        singleInstance: true,
      );
    } catch (e) {
      print('DatabaseHelper: ERROR initializing database: $e');
      rethrow;
    }
  }

  static Future<void> _createTables(Database db, int version) async {
    print('DatabaseHelper: Creating tables...');
    
    // Transactions table with anti-tampering support
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_number INTEGER,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        receipt_path TEXT,
        virtual_bank_id TEXT,
        is_recurring INTEGER DEFAULT 0,
        recurring_frequency TEXT,
        next_due_date INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        edit_history TEXT,
        original_transaction_id INTEGER
      )
    ''');

    // Virtual Banks table
    await db.execute('''
      CREATE TABLE virtual_banks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        target_amount REAL NOT NULL DEFAULT 0.0,
        target_date INTEGER,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        description TEXT,
        type TEXT DEFAULT 'savings',
        debit_source TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        spent REAL DEFAULT 0.0,
        period TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // EMIs table
    await db.execute('''
      CREATE TABLE emis (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        lender_name TEXT NOT NULL,
        principal_amount REAL NOT NULL,
        interest_rate REAL NOT NULL,
        tenure_months INTEGER NOT NULL,
        monthly_emi REAL NOT NULL,
        total_amount REAL NOT NULL,
        total_interest REAL NOT NULL,
        paid_amount REAL DEFAULT 0.0,
        paid_installments INTEGER DEFAULT 0,
        start_date INTEGER NOT NULL,
        next_due_date INTEGER,
        category TEXT NOT NULL,
        description TEXT,
        virtual_bank_id TEXT,
        is_active INTEGER DEFAULT 1,
        auto_debit INTEGER DEFAULT 0,
        auto_debit_day INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    print('DatabaseHelper: All tables created successfully');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('DatabaseHelper: Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      // Migration for adding target_date to virtual_banks table
      try {
        await db.execute('ALTER TABLE virtual_banks ADD COLUMN target_date INTEGER');
      } catch (e) {
        print('Migration warning: $e');
      }
      
      // Migration for adding transaction_number to transactions table
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN transaction_number INTEGER');
      } catch (e) {
        print('Migration warning: $e');
      }
    }
    
    if (oldVersion < 4) {
      // Add anti-tampering columns
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN edit_history TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN original_transaction_id INTEGER');
        print('DatabaseHelper: Added anti-tampering columns');
      } catch (e) {
        print('Migration warning: $e');
      }
    }
  }

  // Transaction operations
  Future<int> insertTransaction(models.Transaction transaction) async {
    print('DatabaseHelper: Inserting transaction - ${transaction.type}: ₹${transaction.amount} - ${transaction.description}');
    print('DatabaseHelper: Transaction ID: ${transaction.id}, Transaction Number: ${transaction.transactionNumber}');
    
    try {
      final db = await database;
      
      final transactionMap = {
        // Do NOT include 'id' in the map to ensure auto-increment works
        'transaction_number': transaction.transactionNumber,
        'type': transaction.type,
        'amount': transaction.amount,
        'category': transaction.category,
        'description': transaction.description,
        'date': transaction.date.millisecondsSinceEpoch,
        'receipt_path': transaction.receiptPath,
        'virtual_bank_id': transaction.virtualBankId,
        'is_recurring': transaction.isRecurring ? 1 : 0,
        'recurring_frequency': transaction.recurringFrequency,
        'next_due_date': transaction.nextDueDate?.millisecondsSinceEpoch,
        'is_active': transaction.isActive ? 1 : 0,
        'created_at': transaction.createdAt.millisecondsSinceEpoch,
        'updated_at': transaction.updatedAt.millisecondsSinceEpoch,
        'edit_history': transaction.editHistory != null 
            ? jsonEncode(transaction.editHistory) 
            : null,
        'original_transaction_id': transaction.originalTransactionId,
      };
      
      print('DatabaseHelper: Transaction map keys: ${transactionMap.keys.toList()}');
      print('DatabaseHelper: is_active value: ${transactionMap['is_active']}');
      print('DatabaseHelper: original_transaction_id: ${transactionMap['original_transaction_id']}');
      
      final id = await db.insert('transactions', transactionMap);
      print('DatabaseHelper: Transaction inserted with NEW ID: $id');
      
      return id;
    } catch (e) {
      print('DatabaseHelper: ERROR inserting transaction: $e');
      return -1;
    }
  }

  Future<List<models.Transaction>> getTransactions({
    String? type,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    bool includeInactive = false, // Add parameter to include inactive transactions
  }) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('transactions');
      
      print('DatabaseHelper: getTransactions - Raw data from database: ${maps.length} records');
      
      List<models.Transaction> transactions = maps
          .map((map) => models.Transaction.fromMap(map))
          .where((t) => includeInactive || t.isActive) // Filter based on includeInactive flag
          .toList();

      print('DatabaseHelper: getTransactions - After filtering active: ${transactions.length} transactions');

      // Apply filters
      if (type != null) {
        transactions = transactions.where((t) => t.type == type).toList();
        print('DatabaseHelper: getTransactions - After type filter ($type): ${transactions.length} transactions');
      }
      
      if (category != null) {
        transactions = transactions.where((t) => t.category == category).toList();
      }
      
      if (startDate != null) {
        transactions = transactions.where((t) => t.date.isAfter(startDate) || t.date.isAtSameMomentAs(startDate)).toList();
      }
      
      if (endDate != null) {
        transactions = transactions.where((t) => t.date.isBefore(endDate) || t.date.isAtSameMomentAs(endDate)).toList();
      }

      // Sort by transaction number (newest first), then by date as fallback
      transactions.sort((a, b) {
        // Primary sort by transaction number (descending - highest numbers first)
        if (a.transactionNumber != null && b.transactionNumber != null) {
          final numberComparison = b.transactionNumber!.compareTo(a.transactionNumber!);
          if (numberComparison != 0) return numberComparison;
        }
        // If one has no transaction number, put it at the end
        if (a.transactionNumber == null && b.transactionNumber != null) return 1;
        if (a.transactionNumber != null && b.transactionNumber == null) return -1;
        
        // Fallback to date sorting (newest first)
        return b.date.compareTo(a.date);
      });
      
      if (limit != null && limit > 0) {
        transactions = transactions.take(limit).toList();
      }

      print('DatabaseHelper: getTransactions - Final result: ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      print('DatabaseHelper: ERROR in getTransactions: $e');
      return [];
    }
  }

  Future<int> updateTransaction(models.Transaction transaction) async {
    final db = await database;
    
    final transactionMap = {
      'type': transaction.type,
      'amount': transaction.amount,
      'category': transaction.category,
      'description': transaction.description,
      'date': transaction.date.millisecondsSinceEpoch,
      'receipt_path': transaction.receiptPath,
      'virtual_bank_id': transaction.virtualBankId,
      'is_recurring': transaction.isRecurring ? 1 : 0,
      'recurring_frequency': transaction.recurringFrequency,
      'next_due_date': transaction.nextDueDate?.millisecondsSinceEpoch,
      'is_active': transaction.isActive ? 1 : 0,
      'created_at': transaction.createdAt.millisecondsSinceEpoch,
      'updated_at': transaction.updatedAt.millisecondsSinceEpoch,
      'edit_history': transaction.editHistory != null 
          ? jsonEncode(transaction.editHistory) 
          : null,
      'original_transaction_id': transaction.originalTransactionId,
    };
    
    return await db.update(
      'transactions',
      transactionMap,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    
    return await db.update(
      'transactions',
      {'is_active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Virtual Bank operations
  Future<int> insertVirtualBank(models.VirtualBank virtualBank) async {
    final db = await database;
    
    final bankMap = {
      'id': virtualBank.id,
      'name': virtualBank.name,
      'balance': virtualBank.balance,
      'target_amount': virtualBank.targetAmount,
      'target_date': virtualBank.targetDate?.millisecondsSinceEpoch, // Handle target date
      'color': virtualBank.color,
      'icon': virtualBank.icon,
      'description': virtualBank.description,
      'created_at': virtualBank.createdAt.millisecondsSinceEpoch,
      'updated_at': virtualBank.updatedAt.millisecondsSinceEpoch,
    };
    
    return await db.insert('virtual_banks', bankMap);
  }

  Future<List<models.VirtualBank>> getVirtualBanks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('virtual_banks');
    
    return maps
        .map((map) => models.VirtualBank.fromMap(map))
        .toList();
  }

  Future<models.VirtualBank?> getVirtualBank(String id) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'virtual_banks',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return models.VirtualBank.fromMap(maps.first);
    }
    
    return null;
  }

  Future<int> updateVirtualBank(models.VirtualBank virtualBank) async {
    final db = await database;
    
    final bankMap = {
      'id': virtualBank.id,
      'name': virtualBank.name,
      'balance': virtualBank.balance,
      'target_amount': virtualBank.targetAmount,
      'target_date': virtualBank.targetDate?.millisecondsSinceEpoch, // Handle target date
      'color': virtualBank.color,
      'icon': virtualBank.icon,
      'description': virtualBank.description,
      'created_at': virtualBank.createdAt.millisecondsSinceEpoch,
      'updated_at': virtualBank.updatedAt.millisecondsSinceEpoch,
    };
    
    return await db.update(
      'virtual_banks',
      bankMap,
      where: 'id = ?',
      whereArgs: [virtualBank.id],
    );
  }

  Future<int> deleteVirtualBank(String id) async {
    final db = await database;
    
    return await db.delete(
      'virtual_banks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Budget operations
  Future<int> insertBudget(models.Budget budget) async {
    final db = await database;
    
    final budgetMap = {
      'category': budget.category,
      'amount': budget.amount,
      'spent': budget.spent,
      'period': budget.period,
      'start_date': budget.startDate.millisecondsSinceEpoch,
      'end_date': budget.endDate.millisecondsSinceEpoch,
      'is_active': budget.isActive ? 1 : 0,
      'created_at': budget.createdAt.millisecondsSinceEpoch,
      'updated_at': budget.updatedAt.millisecondsSinceEpoch,
    };
    
    return await db.insert('budgets', budgetMap);
  }

  Future<List<models.Budget>> getBudgets({bool? isActive}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('budgets');
    
    List<models.Budget> budgets = maps
        .map((map) => models.Budget.fromMap(map))
        .toList();

    if (isActive != null) {
      budgets = budgets.where((b) => b.isActive == isActive).toList();
    }

    return budgets;
  }

  Future<int> updateBudget(models.Budget budget) async {
    final db = await database;
    
    final budgetMap = {
      'category': budget.category,
      'amount': budget.amount,
      'spent': budget.spent,
      'period': budget.period,
      'start_date': budget.startDate.millisecondsSinceEpoch,
      'end_date': budget.endDate.millisecondsSinceEpoch,
      'is_active': budget.isActive ? 1 : 0,
      'created_at': budget.createdAt.millisecondsSinceEpoch,
      'updated_at': budget.updatedAt.millisecondsSinceEpoch,
    };
    
    return await db.update(
      'budgets',
      budgetMap,
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    
    return await db.update(
      'budgets',
      {'is_active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // EMI operations
  Future<int> insertEMI(models.EMI emi) async {
    final db = await database;
    
    final emiMap = {
      'id': emi.id,
      'name': emi.name,
      'lender_name': emi.lenderName,
      'principal_amount': emi.principalAmount,
      'interest_rate': emi.interestRate,
      'tenure_months': emi.tenureMonths,
      'monthly_emi': emi.monthlyEMI,
      'total_amount': emi.totalAmount,
      'total_interest': emi.totalInterest,
      'paid_amount': emi.paidAmount,
      'paid_installments': emi.paidInstallments,
      'start_date': emi.startDate.millisecondsSinceEpoch,
      'next_due_date': emi.nextDueDate?.millisecondsSinceEpoch,
      'category': emi.category,
      'description': emi.description,
      'virtual_bank_id': emi.virtualBankId,
      'is_active': emi.isActive ? 1 : 0,
      'auto_debit': emi.autoDebit ? 1 : 0,
      'auto_debit_day': emi.autoDebitDay,
      'created_at': emi.createdAt.millisecondsSinceEpoch,
      'updated_at': emi.updatedAt.millisecondsSinceEpoch,
    };
    
    return await db.insert('emis', emiMap);
  }

  Future<List<models.EMI>> getEMIs({bool? isActive}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('emis');
    
    List<models.EMI> emis = maps
        .map((map) => models.EMI.fromMap(map))
        .toList();

    if (isActive != null) {
      emis = emis.where((e) => e.isActive == isActive).toList();
    }

    // Sort by next due date
    emis.sort((a, b) {
      if (a.nextDueDate == null && b.nextDueDate == null) return 0;
      if (a.nextDueDate == null) return 1;
      if (b.nextDueDate == null) return -1;
      return a.nextDueDate!.compareTo(b.nextDueDate!);
    });

    return emis;
  }

  Future<models.EMI?> getEMI(String id) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'emis',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return models.EMI.fromMap(maps.first);
    }
    
    return null;
  }

  Future<int> updateEMI(models.EMI emi) async {
    final db = await database;
    
    final emiMap = {
      'name': emi.name,
      'lender_name': emi.lenderName,
      'principal_amount': emi.principalAmount,
      'interest_rate': emi.interestRate,
      'tenure_months': emi.tenureMonths,
      'monthly_emi': emi.monthlyEMI,
      'total_amount': emi.totalAmount,
      'total_interest': emi.totalInterest,
      'paid_amount': emi.paidAmount,
      'paid_installments': emi.paidInstallments,
      'start_date': emi.startDate.millisecondsSinceEpoch,
      'next_due_date': emi.nextDueDate?.millisecondsSinceEpoch,
      'category': emi.category,
      'description': emi.description,
      'virtual_bank_id': emi.virtualBankId,
      'is_active': emi.isActive ? 1 : 0,
      'auto_debit': emi.autoDebit ? 1 : 0,
      'auto_debit_day': emi.autoDebitDay,
      'updated_at': emi.updatedAt.millisecondsSinceEpoch,
    };
    
    return await db.update(
      'emis',
      emiMap,
      where: 'id = ?',
      whereArgs: [emi.id],
    );
  }

  Future<int> deleteEMI(String id) async {
    final db = await database;
    
    return await db.update(
      'emis',
      {'is_active': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> payEMIInstallment(String emiId, double amount) async {
    final db = await database;
    final emi = await getEMI(emiId);
    
    if (emi == null) return 0;
    
    final newPaidAmount = emi.paidAmount + amount;
    final newPaidInstallments = emi.paidInstallments + 1;
    
    // Calculate next due date (add 1 month)
    DateTime? nextDueDate;
    if (newPaidInstallments < emi.tenureMonths) {
      final currentDue = emi.nextDueDate ?? emi.startDate;
      nextDueDate = DateTime(currentDue.year, currentDue.month + 1, currentDue.day);
    }
    
    final emiMap = {
      'paid_amount': newPaidAmount,
      'paid_installments': newPaidInstallments,
      'next_due_date': nextDueDate?.millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    
    return await db.update(
      'emis',
      emiMap,
      where: 'id = ?',
      whereArgs: [emiId],
    );
  }

  // Analytics queries
  Future<Map<String, double>> getExpensesByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final transactions = await getTransactions(
      type: 'expense',
      startDate: startDate,
      endDate: endDate,
    );

    Map<String, double> expenses = {};
    for (var transaction in transactions) {
      expenses[transaction.category] = (expenses[transaction.category] ?? 0) + transaction.amount;
    }

    return expenses;
  }

  Future<List<Map<String, dynamic>>> getMonthlyTrends({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final transactions = await getTransactions(
      startDate: startDate,
      endDate: endDate,
    );

    Map<String, Map<String, double>> monthlyData = {};
    
    for (var transaction in transactions) {
      final monthKey = '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';
      
      if (!monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = {'income': 0.0, 'expense': 0.0};
      }
      
      monthlyData[monthKey]![transaction.type] = 
          (monthlyData[monthKey]![transaction.type] ?? 0) + transaction.amount;
    }

    List<Map<String, dynamic>> result = [];
    for (var entry in monthlyData.entries) {
      for (var typeEntry in entry.value.entries) {
        result.add({
          'month': entry.key,
          'type': typeEntry.key,
          'total': typeEntry.value,
        });
      }
    }

    return result;
  }

  Future<double> getTotalBalance() async {
    final transactions = await getTransactions();
    
    double totalIncome = 0.0;
    double totalExpense = 0.0;
    
    for (var transaction in transactions) {
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
      } else if (transaction.type == 'expense') {
        totalExpense += transaction.amount;
      }
    }

    return totalIncome - totalExpense;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Development helper methods - REMOVED FOR PRODUCTION
  // Users should get a clean app experience on first use
  
  // Method to clear all data if needed (for development/testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('virtual_banks');
    await db.delete('budgets');
    await db.delete('emis');
  }
}