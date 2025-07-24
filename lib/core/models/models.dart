class Transaction {
  final int? id;
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

  Transaction({
    this.id,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'receiptPath': receiptPath,
      'virtualBankId': virtualBankId,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringFrequency': recurringFrequency,
      'nextDueDate': nextDueDate?.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
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
    );
  }

  Transaction copyWith({
    int? id,
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
  }) {
    return Transaction(
      id: id ?? this.id,
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
    );
  }
}

class VirtualBank {
  final String id;
  final String name;
  final double balance;
  final double targetAmount;
  final String color; // Hex color code
  final String icon;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  VirtualBank({
    required this.id,
    required this.name,
    required this.balance,
    required this.targetAmount,
    required this.color,
    required this.icon,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'targetAmount': targetAmount,
      'color': color,
      'icon': icon,
      'description': description,
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
      color: map['color'],
      icon: map['icon'],
      description: map['description'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
    );
  }

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    return (balance / targetAmount).clamp(0.0, 1.0);
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
}