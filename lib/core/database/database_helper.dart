import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart' as models;

// Add web-specific imports
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize web database factory if on web
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    
    // Use a consistent database name
    String dbName = 'cost_manager.db';
    String path;
    
    if (kIsWeb) {
      // For web, use just the database name - it will be stored in IndexedDB
      path = dbName;
    } else {
      // For mobile platforms (iOS/Android), use the proper path
      path = join(await getDatabasesPath(), dbName);
    }
    
    print('DatabaseHelper: Initializing database at: $path');
    print('DatabaseHelper: Platform: ${kIsWeb ? 'Web' : 'Native'}');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
      readOnly: false,
      singleInstance: true,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    print('DatabaseHelper: Creating tables...');
    
    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        updated_at INTEGER NOT NULL
      )
    ''');

    // Virtual Banks table
    await db.execute('''
      CREATE TABLE virtual_banks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        target_amount REAL NOT NULL DEFAULT 0.0,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        description TEXT,
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

    print('DatabaseHelper: All tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('DatabaseHelper: Upgrading database from version $oldVersion to $newVersion');
    // Handle database upgrades here if needed in future versions
  }

  // Transaction operations
  Future<int> insertTransaction(models.Transaction transaction) async {
    print('DatabaseHelper: Inserting transaction - ${transaction.type}: ₹${transaction.amount} - ${transaction.description}');
    
    try {
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
      };
      
      final id = await db.insert('transactions', transactionMap);
      print('DatabaseHelper: Transaction inserted with ID: $id');
      
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
  }) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('transactions');
      
      print('DatabaseHelper: getTransactions - Raw data from database: ${maps.length} records');
      
      List<models.Transaction> transactions = maps
          .map((map) => models.Transaction.fromMap(map))
          .where((t) => t.isActive)
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

      // Sort by date (newest first)
      transactions.sort((a, b) => b.date.compareTo(a.date));
      
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

  // Development helper methods
  Future<void> addSampleData() async {
    print('DatabaseHelper: Adding sample data for testing...');
    
    try {
      // Add sample transactions
      final sampleTransactions = [
        models.Transaction(
          id: 1,
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
        models.Transaction(
          id: 2,
          type: 'expense',
          amount: 1200.0,
          category: 'Food',
          description: 'Grocery Shopping',
          date: DateTime.now().subtract(const Duration(days: 2)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        models.Transaction(
          id: 3,
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
        models.Transaction(
          id: 4,
          type: 'income',
          amount: 2000.0,
          category: 'Freelance',
          description: 'Web Development Project',
          date: DateTime.now().subtract(const Duration(days: 3)),
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      for (var transaction in sampleTransactions) {
        await insertTransaction(transaction);
      }

      // Add sample virtual bank
      final sampleBank = models.VirtualBank(
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

      await insertVirtualBank(sampleBank);

      print('DatabaseHelper: Sample data added successfully');
    } catch (e) {
      print('DatabaseHelper: ERROR adding sample data: $e');
    }
  }

  Future<void> clearAllData() async {
    print('DatabaseHelper: Clearing all data...');
    
    try {
      final db = await database;
      
      await db.delete('transactions');
      await db.delete('virtual_banks');
      await db.delete('budgets');
      
      print('DatabaseHelper: All data cleared successfully');
    } catch (e) {
      print('DatabaseHelper: ERROR clearing data: $e');
    }
  }
}