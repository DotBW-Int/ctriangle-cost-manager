import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class CreateEMIDialog extends StatefulWidget {
  final EMI? emi; // For editing existing EMI

  const CreateEMIDialog({super.key, this.emi});

  @override
  State<CreateEMIDialog> createState() => _CreateEMIDialogState();
}

class _CreateEMIDialogState extends State<CreateEMIDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lenderController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _tenureController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'home_loan';
  DateTime _startDate = DateTime.now();
  String? _selectedVirtualBankId;
  bool _autoDebit = false;
  int _autoDebitDay = 1;
  double _calculatedEMI = 0.0;

  final List<EMICategoryOption> _categoryOptions = [
    EMICategoryOption('home_loan', Icons.home, 'Home Loan', '#2196F3'),
    EMICategoryOption('car_loan', Icons.directions_car, 'Car Loan', '#FF9800'),
    EMICategoryOption('personal_loan', Icons.person, 'Personal Loan', '#9C27B0'),
    EMICategoryOption('credit_card', Icons.credit_card, 'Credit Card', '#F44336'),
    EMICategoryOption('education_loan', Icons.school, 'Education Loan', '#4CAF50'),
    EMICategoryOption('business_loan', Icons.business, 'Business Loan', '#795548'),
    EMICategoryOption('other', Icons.account_balance, 'Other', '#607D8B'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.emi != null) {
      _populateFieldsForEdit();
    }
  }

  void _populateFieldsForEdit() {
    final emi = widget.emi!;
    _nameController.text = emi.name;
    _lenderController.text = emi.lenderName;
    _principalController.text = emi.principalAmount.toString();
    _interestController.text = emi.interestRate.toString();
    _tenureController.text = emi.tenureMonths.toString();
    _descriptionController.text = emi.description ?? '';
    _selectedCategory = emi.category;
    _startDate = emi.startDate;
    _selectedVirtualBankId = emi.virtualBankId;
    _autoDebit = emi.autoDebit;
    _autoDebitDay = emi.autoDebitDay ?? 1;
    _calculatedEMI = emi.monthlyEMI;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicFields(),
                      const SizedBox(height: 20),
                      _buildLoanDetails(),
                      const SizedBox(height: 20),
                      _buildCategorySelector(),
                      const SizedBox(height: 20),
                      _buildDateField(),
                      const SizedBox(height: 20),
                      _buildVirtualBankSelector(),
                      const SizedBox(height: 20),
                      _buildAutoDebitSection(),
                      if (_calculatedEMI > 0) ...[
                        const SizedBox(height: 20),
                        _buildEMICalculation(),
                      ],
                      const SizedBox(height: 30),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      widget.emi == null ? 'Add New EMI' : 'Edit EMI',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track your loan payments effortlessly',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          // Progress indicator
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFields() {
    return Column(
      children: [
        _buildNameField(),
        const SizedBox(height: 16),
        _buildLenderField(),
        const SizedBox(height: 16),
        _buildDescriptionField(),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EMI Name',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g., Home Loan, Car EMI',
            prefixIcon: const Icon(Icons.label),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter EMI name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildLenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lender Name',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _lenderController,
          decoration: InputDecoration(
            hintText: 'e.g., SBI, HDFC Bank',
            prefixIcon: const Icon(Icons.business),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter lender name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'Additional notes about this EMI',
            prefixIcon: const Icon(Icons.notes),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildLoanDetails() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPrincipalField()),
            const SizedBox(width: 12),
            Expanded(child: _buildInterestField()),
          ],
        ),
        const SizedBox(height: 16),
        _buildTenureField(),
      ],
    );
  }

  Widget _buildPrincipalField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Principal Amount',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _principalController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '500000',
            prefixText: '₹ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => _calculateEMI(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter amount';
            }
            if (double.tryParse(value) == null || double.parse(value) <= 0) {
              return 'Invalid amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInterestField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest Rate',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _interestController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '8.5',
            suffixText: '% p.a.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => _calculateEMI(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter rate';
            }
            if (double.tryParse(value) == null || double.parse(value) < 0) {
              return 'Invalid rate';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTenureField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tenure (Months)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _tenureController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '240',
            suffixText: 'months',
            prefixIcon: const Icon(Icons.schedule),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (_) => _calculateEMI(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter tenure';
            }
            if (int.tryParse(value) == null || int.parse(value) <= 0) {
              return 'Invalid tenure';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryOptions.map((option) => _buildCategoryOption(option)).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryOption(EMICategoryOption option) {
    final isSelected = _selectedCategory == option.value;
    final color = Color(int.parse(option.color.replaceFirst('#', '0xFF')));
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = option.value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              color: isSelected ? color : Theme.of(context).iconTheme.color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: TextStyle(
                color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Date',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 12),
                Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualBankSelector() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pay from Virtual Bank (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedVirtualBankId,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_balance),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Select Virtual Bank'),
                ),
                ...financeProvider.virtualBanks.map((bank) {
                  return DropdownMenuItem<String>(
                    value: bank.id,
                    child: Text(bank.name),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedVirtualBankId = value;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAutoDebitSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _autoDebit,
              onChanged: (value) {
                setState(() {
                  _autoDebit = value ?? false;
                });
              },
              activeColor: AppTheme.primaryBlue,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Auto-Debit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Automatically pay EMI on due date',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_autoDebit) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _autoDebitDay,
            decoration: InputDecoration(
              labelText: 'Auto-Debit Day of Month',
              prefixIcon: const Icon(Icons.today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            items: List.generate(28, (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('${index + 1}${_getOrdinalSuffix(index + 1)}'),
            )),
            onChanged: (value) {
              setState(() {
                _autoDebitDay = value!;
              });
            },
          ),
        ],
      ],
    );
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildEMICalculation() {
    final principal = double.tryParse(_principalController.text) ?? 0;
    final totalAmount = _calculatedEMI * (int.tryParse(_tenureController.text) ?? 0);
    final totalInterest = totalAmount - principal;

    return Card(
      color: AppTheme.primaryBlue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  'EMI Calculation',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCalculationRow('Monthly EMI:', _calculatedEMI),
            _buildCalculationRow('Total Amount:', totalAmount),
            _buildCalculationRow('Total Interest:', totalInterest, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹${NumberFormat('#,##,###').format(value)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveEMI,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(
              widget.emi == null ? 'Add EMI' : 'Update EMI',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  void _calculateEMI() {
    final principal = double.tryParse(_principalController.text);
    final rate = double.tryParse(_interestController.text);
    final tenure = int.tryParse(_tenureController.text);

    if (principal != null && rate != null && tenure != null && 
        principal > 0 && rate >= 0 && tenure > 0) {
      setState(() {
        _calculatedEMI = EMI.calculateEMI(principal, rate, tenure);
      });
    } else {
      setState(() {
        _calculatedEMI = 0.0;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _saveEMI() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final principal = double.parse(_principalController.text);
      final rate = double.parse(_interestController.text);
      final tenure = int.parse(_tenureController.text);

      if (widget.emi == null) {
        // Create new EMI
        await context.read<FinanceProvider>().createEMI(
          name: _nameController.text.trim(),
          lenderName: _lenderController.text.trim(),
          principalAmount: principal,
          interestRate: rate,
          tenureMonths: tenure,
          startDate: _startDate,
          category: _selectedCategory,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          virtualBankId: _selectedVirtualBankId,
          autoDebit: _autoDebit,
          autoDebitDay: _autoDebit ? _autoDebitDay : null,
        );
      } else {
        // Update existing EMI
        final updatedEMI = widget.emi!.copyWith(
          name: _nameController.text.trim(),
          lenderName: _lenderController.text.trim(),
          principalAmount: principal,
          interestRate: rate,
          tenureMonths: tenure,
          monthlyEMI: _calculatedEMI,
          totalAmount: _calculatedEMI * tenure,
          totalInterest: (_calculatedEMI * tenure) - principal,
          startDate: _startDate,
          category: _selectedCategory,
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          virtualBankId: _selectedVirtualBankId,
          autoDebit: _autoDebit,
          autoDebitDay: _autoDebit ? _autoDebitDay : null,
          updatedAt: DateTime.now(),
        );
        
        await context.read<FinanceProvider>().updateEMI(updatedEMI);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.emi == null 
              ? 'EMI added successfully' 
              : 'EMI updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lenderController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _tenureController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class EMICategoryOption {
  final String value;
  final IconData icon;
  final String label;
  final String color;

  EMICategoryOption(this.value, this.icon, this.label, this.color);
}