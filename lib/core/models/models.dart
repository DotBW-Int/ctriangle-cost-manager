import 'dart:math' as math;
import 'dart:convert';

class Transaction {
  final int? id;
  final int? transactionNumber; // Add transaction numbering
  final String type; // 'expense', 'income', 'transfer', 'recurring'
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String? receiptPath;
  final String? virtualBankId;
  final bool isRecurring;
  final String? recurringFrequency; // 'monthly', 'weekly', 'yearly'
  final DateTime? nextDueDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>>? editHistory; // Add edit history support
  final int? originalTransactionId; // Link to original transaction for anti-tampering

  Transaction({
    this.id,
    this.transactionNumber,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.receiptPath,
    this.virtualBankId,
    this.isRecurring = false,
    this.recurringFrequency,
    this.nextDueDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.editHistory,
    this.originalTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_number': transactionNumber,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'receipt_path': receiptPath,
      'virtual_bank_id': virtualBankId,
      'is_recurring': isRecurring ? 1 : 0,
      'recurring_frequency': recurringFrequency,
      'next_due_date': nextDueDate?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'edit_history': editHistory != null ? jsonEncode(editHistory) : null,
      'original_transaction_id': originalTransactionId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      transactionNumber: map['transaction_number'],
      type: map['type'],
      amount: map['amount'].toDouble(),
      category: map['category'],
      description: map['description'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      receiptPath: map['receipt_path'],
      virtualBankId: map['virtual_bank_id'],
      isRecurring: map['is_recurring'] == 1,
      recurringFrequency: map['recurring_frequency'],
      nextDueDate: map['next_due_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['next_due_date'])
          : null,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      editHistory: map['edit_history'] != null ? _parseEditHistory(map['edit_history']) : null,
      originalTransactionId: map['original_transaction_id'],
    );
  }

  static List<Map<String, dynamic>>? _parseEditHistory(String? editHistoryStr) {
    if (editHistoryStr == null || editHistoryStr.isEmpty) return null;
    
    try {
      // First, try to parse as proper JSON
      final decoded = jsonDecode(editHistoryStr) as List;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error parsing edit history as JSON: $e');
      print('Raw edit history string: $editHistoryStr');
      
      // If JSON parsing fails, it might be in Dart toString format
      // For now, return null to prevent crashes
      // TODO: Consider migrating old data to proper JSON format
      return null;
    }
  }

  // Check if this transaction has been edited
  bool get hasBeenEdited => editHistory != null && editHistory!.isNotEmpty;

  // Get the number of times this transaction has been edited
  int get editCount => editHistory?.length ?? 0;

  // Get the last edit timestamp
  DateTime? get lastEditTime {
    if (editHistory == null || editHistory!.isEmpty) return null;
    final lastEdit = editHistory!.last;
    return DateTime.fromMillisecondsSinceEpoch(lastEdit['timestamp'] ?? 0);
  }

  // Get formatted edit summary
  String get editSummary {
    if (!hasBeenEdited) return 'No edits';
    return 'Edited ${editCount} time${editCount > 1 ? 's' : ''} • Last: ${_formatEditTime(lastEditTime)}';
  }

  String _formatEditTime(DateTime? time) {
    if (time == null) return 'Unknown';
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Transaction copyWith({
    int? id,
    int? transactionNumber,
    String? type,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    String? receiptPath,
    String? virtualBankId,
    bool? isRecurring,
    String? recurringFrequency,
    DateTime? nextDueDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? editHistory,
    int? originalTransactionId,
  }) {
    return Transaction(
      id: id ?? this.id,
      transactionNumber: transactionNumber ?? this.transactionNumber,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      receiptPath: receiptPath ?? this.receiptPath,
      virtualBankId: virtualBankId ?? this.virtualBankId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringFrequency: recurringFrequency ?? this.recurringFrequency,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      editHistory: editHistory ?? this.editHistory,
      originalTransactionId: originalTransactionId ?? this.originalTransactionId,
    );
  }
}

class VirtualBank {
  final String id;
  final String name;
  final double balance;
  final double targetAmount;
  final DateTime? targetDate; // Added targetDate property
  final String color; // Hex color code
  final String icon;
  final String description;
  final String type; // 'savings', 'current', 'fixed'
  final String? debitSource; // 'bank_account', 'credit_card', 'debit_card'
  final DateTime createdAt;
  final DateTime updatedAt;

  VirtualBank({
    required this.id,
    required this.name,
    required this.balance,
    required this.targetAmount,
    this.targetDate, // Added targetDate parameter
    required this.color,
    required this.icon,
    required this.description,
    this.type = 'savings',
    this.debitSource,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'targetAmount': targetAmount,
      'targetDate': targetDate?.millisecondsSinceEpoch, // Added targetDate to map
      'color': color,
      'icon': icon,
      'description': description,
      'type': type,
      'debitSource': debitSource,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory VirtualBank.fromMap(Map<String, dynamic> map) {
    return VirtualBank(
      id: map['id'],
      name: map['name'],
      balance: map['balance'].toDouble(),
      targetAmount: map['target_amount'].toDouble(),
      targetDate: map['target_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['target_date'])
          : null, // Added targetDate from map
      color: map['color'],
      icon: map['icon'],
      description: map['description'],
      type: map['type'] ?? 'savings',
      debitSource: map['debit_source'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    return (balance / targetAmount).clamp(0.0, 1.0);
  }

  VirtualBank copyWith({
    String? id,
    String? name,
    double? balance,
    double? targetAmount,
    DateTime? targetDate,
    String? color,
    String? icon,
    String? description,
    String? type,
    String? debitSource,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VirtualBank(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: targetDate ?? this.targetDate,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      type: type ?? this.type,
      debitSource: debitSource ?? this.debitSource,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Budget {
  final int? id;
  final String category;
  final double amount;
  final double spent;
  final String period; // 'monthly', 'weekly', 'yearly'
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget({
    this.id,
    required this.category,
    required this.amount,
    this.spent = 0.0,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'spent': spent,
      'period': period,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      amount: map['amount'].toDouble(),
      spent: map['spent'].toDouble(),
      period: map['period'],
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date']),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['end_date']),
      isActive: map['is_active'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  double get remainingAmount => amount - spent;
  double get progressPercentage => amount > 0 ? (spent / amount).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => spent > amount;

  Budget copyWith({
    int? id,
    String? category,
    double? amount,
    double? spent,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EMI {
  final String id;
  final String name;
  final String lenderName;
  final double principalAmount;
  final double interestRate; // Annual interest rate in percentage
  final int tenureMonths;
  final double monthlyEMI;
  final double totalAmount;
  final double totalInterest;
  final double paidAmount;
  final int paidInstallments;
  final DateTime startDate;
  final DateTime? nextDueDate;
  final String category; // 'home_loan', 'car_loan', 'personal_loan', 'credit_card', 'other'
  final String? description;
  final String? virtualBankId; // Optional: pay from virtual bank
  final bool isActive;
  final bool autoDebit;
  final int? autoDebitDay; // Day of month for auto debit (1-31)
  final DateTime createdAt;
  final DateTime updatedAt;

  EMI({
    required this.id,
    required this.name,
    required this.lenderName,
    required this.principalAmount,
    required this.interestRate,
    required this.tenureMonths,
    required this.monthlyEMI,
    required this.totalAmount,
    required this.totalInterest,
    this.paidAmount = 0.0,
    this.paidInstallments = 0,
    required this.startDate,
    this.nextDueDate,
    required this.category,
    this.description,
    this.virtualBankId,
    this.isActive = true,
    this.autoDebit = false,
    this.autoDebitDay,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lender_name': lenderName,
      'principal_amount': principalAmount,
      'interest_rate': interestRate,
      'tenure_months': tenureMonths,
      'monthly_emi': monthlyEMI,
      'total_amount': totalAmount,
      'total_interest': totalInterest,
      'paid_amount': paidAmount,
      'paid_installments': paidInstallments,
      'start_date': startDate.millisecondsSinceEpoch,
      'next_due_date': nextDueDate?.millisecondsSinceEpoch,
      'category': category,
      'description': description,
      'virtual_bank_id': virtualBankId,
      'is_active': isActive ? 1 : 0,
      'auto_debit': autoDebit ? 1 : 0,
      'auto_debit_day': autoDebitDay,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory EMI.fromMap(Map<String, dynamic> map) {
    return EMI(
      id: map['id'],
      name: map['name'],
      lenderName: map['lender_name'],
      principalAmount: map['principal_amount'].toDouble(),
      interestRate: map['interest_rate'].toDouble(),
      tenureMonths: map['tenure_months'],
      monthlyEMI: map['monthly_emi'].toDouble(),
      totalAmount: map['total_amount'].toDouble(),
      totalInterest: map['total_interest'].toDouble(),
      paidAmount: map['paid_amount']?.toDouble() ?? 0.0,
      paidInstallments: map['paid_installments'] ?? 0,
      startDate: DateTime.fromMillisecondsSinceEpoch(map['start_date']),
      nextDueDate: map['next_due_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['next_due_date'])
          : null,
      category: map['category'],
      description: map['description'],
      virtualBankId: map['virtual_bank_id'],
      isActive: map['is_active'] == 1,
      autoDebit: map['auto_debit'] == 1,
      autoDebitDay: map['auto_debit_day'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  // Calculated properties
  double get remainingAmount => totalAmount - paidAmount;
  int get remainingInstallments => tenureMonths - paidInstallments;
  double get progressPercentage => tenureMonths > 0 ? (paidInstallments / tenureMonths).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => paidInstallments >= tenureMonths;
  double get principalRemaining => principalAmount - (paidAmount - (paidInstallments * monthlyEMI - principalAmount));

  // Calculate EMI using formula: P[r(1+r)^n]/[(1+r)^n-1]
  static double calculateEMI(double principal, double annualRate, int months) {
    if (annualRate == 0) return principal / months;
    
    double monthlyRate = annualRate / (12 * 100);
    double factor = 1 + monthlyRate;
    double emi = principal * monthlyRate * (math.pow(factor, months)) / (math.pow(factor, months) - 1);
    return emi;
  }

  EMI copyWith({
    String? id,
    String? name,
    String? lenderName,
    double? principalAmount,
    double? interestRate,
    int? tenureMonths,
    double? monthlyEMI,
    double? totalAmount,
    double? totalInterest,
    double? paidAmount,
    int? paidInstallments,
    DateTime? startDate,
    DateTime? nextDueDate,
    String? category,
    String? description,
    String? virtualBankId,
    bool? isActive,
    bool? autoDebit,
    int? autoDebitDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EMI(
      id: id ?? this.id,
      name: name ?? this.name,
      lenderName: lenderName ?? this.lenderName,
      principalAmount: principalAmount ?? this.principalAmount,
      interestRate: interestRate ?? this.interestRate,
      tenureMonths: tenureMonths ?? this.tenureMonths,
      monthlyEMI: monthlyEMI ?? this.monthlyEMI,
      totalAmount: totalAmount ?? this.totalAmount,
      totalInterest: totalInterest ?? this.totalInterest,
      paidAmount: paidAmount ?? this.paidAmount,
      paidInstallments: paidInstallments ?? this.paidInstallments,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      category: category ?? this.category,
      description: description ?? this.description,
      virtualBankId: virtualBankId ?? this.virtualBankId,
      isActive: isActive ?? this.isActive,
      autoDebit: autoDebit ?? this.autoDebit,
      autoDebitDay: autoDebitDay ?? this.autoDebitDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}