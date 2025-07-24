import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

class CreateVirtualBankDialog extends StatefulWidget {
  const CreateVirtualBankDialog({super.key});

  @override
  State<CreateVirtualBankDialog> createState() => _CreateVirtualBankDialogState();
}

class _CreateVirtualBankDialogState extends State<CreateVirtualBankDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _autoSaveAmountController = TextEditingController();
  
  String _selectedIcon = 'savings';
  String _selectedColor = '#4CAF50';
  bool _enableAutoSave = false;
  String _autoSaveFrequency = 'monthly';
  int _autoSaveDay = 1;
  DateTime? _targetDate; // Add target date field
  
  final List<IconOption> _iconOptions = [
    IconOption('savings', Icons.savings, 'Savings'),
    IconOption('security', Icons.security, 'Emergency'),
    IconOption('flight', Icons.flight, 'Travel'),
    IconOption('home', Icons.home, 'Home'),
    IconOption('car', Icons.directions_car, 'Vehicle'),
    IconOption('school', Icons.school, 'Education'),
    IconOption('medical_services', Icons.medical_services, 'Medical'),
    IconOption('celebration', Icons.celebration, 'Events'),
    IconOption('account_balance', Icons.account_balance, 'Loan EMI'),
    IconOption('credit_card', Icons.credit_card, 'Credit Card'),
    IconOption('business', Icons.business, 'Investment'),
    IconOption('wallet', Icons.wallet, 'Emergency Fund'),
  ];
  
  final List<ColorOption> _colorOptions = [
    ColorOption('#4CAF50', 'Green'),
    ColorOption('#2196F3', 'Blue'),
    ColorOption('#FF9800', 'Orange'),
    ColorOption('#9C27B0', 'Purple'),
    ColorOption('#F44336', 'Red'),
    ColorOption('#00BCD4', 'Cyan'),
    ColorOption('#795548', 'Brown'),
    ColorOption('#607D8B', 'Blue Grey'),
    ColorOption('#E91E63', 'Pink'),
    ColorOption('#FF5722', 'Deep Orange'),
  ];

  String _selectedType = 'savings'; // New field for bank type
  String? _selectedDebitSource; // New field for debit source

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
                      _buildNameField(),
                      const SizedBox(height: 20),
                      _buildTargetAmountField(),
                      const SizedBox(height: 20),
                      _buildDescriptionField(),
                      const SizedBox(height: 20),
                      _buildIconSelector(),
                      const SizedBox(height: 20),
                      _buildColorSelector(),
                      const SizedBox(height: 20),
                      _buildBankTypeSelector(),
                      const SizedBox(height: 20),
                      _buildDebitSourceSelector(),
                      const SizedBox(height: 20),
                      _buildTargetDateSelector(), // Add target date selector
                      const SizedBox(height: 20),
                      _buildAutoSaveSection(),
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
                    const Text(
                      'Create Virtual Bank',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Set up automated savings for your goals',
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
              widthFactor: 0.6,
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

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Name',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'e.g., Emergency Fund, Vacation Savings',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a bank name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTargetAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Amount',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _targetAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '50,000',
            prefixText: '₹ ',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a target amount';
            }
            final cleanValue = value.replaceAll(',', '');
            if (double.tryParse(cleanValue) == null) {
              return 'Please enter a valid amount';
            }
            if (double.parse(cleanValue) <= 0) {
              return 'Target amount must be greater than 0';
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
            hintText: 'What are you saving for?',
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

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Icon',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _iconOptions.map((option) => _buildIconOption(option)).toList(),
        ),
      ],
    );
  }

  Widget _buildIconOption(IconOption option) {
    final isSelected = _selectedIcon == option.value;
    final color = Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIcon = option.value;
        });
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          option.icon,
          color: isSelected ? color : Theme.of(context).iconTheme.color,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Color',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colorOptions.map((option) => _buildColorOption(option)).toList(),
        ),
      ],
    );
  }

  Widget _buildColorOption(ColorOption option) {
    final isSelected = _selectedColor == option.value;
    final color = Color(int.parse(option.value.replaceFirst('#', '0xFF')));
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = option.value;
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildBankTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          items: const [
            DropdownMenuItem(value: 'savings', child: Text('Savings')),
            DropdownMenuItem(value: 'current', child: Text('Current')),
            DropdownMenuItem(value: 'fixed', child: Text('Fixed Deposit')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedType = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDebitSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Debit Source',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDebitSource,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          items: const [
            DropdownMenuItem(value: 'bank_account', child: Text('Bank Account')),
            DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
            DropdownMenuItem(value: 'debit_card', child: Text('Debit Card')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedDebitSource = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTargetDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Date',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: _targetDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      primary: AppTheme.primaryBlue,
                      secondary: AppTheme.primaryBlue,
                    ),
                  ),
                  child: child ?? const SizedBox(),
                );
              },
            );
            if (selectedDate != null) {
              setState(() {
                _targetDate = selectedDate;
              });
            }
          },
          child: AbsorbPointer(
            child: TextFormField(
              decoration: InputDecoration(
                hintText: 'Select target date',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              controller: TextEditingController(
                text: _targetDate != null ? 
                  '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}' : '',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoSaveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _enableAutoSave,
              onChanged: (value) {
                setState(() {
                  _enableAutoSave = value ?? false;
                });
              },
              activeColor: AppTheme.primaryBlue,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Auto-Save',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Automatically transfer money to this bank',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_enableAutoSave) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _autoSaveAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Auto-Save Amount',
                    hintText: '5,000',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  validator: _enableAutoSave ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter amount';
                    }
                    final cleanValue = value.replaceAll(',', '');
                    if (double.tryParse(cleanValue) == null) {
                      return 'Invalid amount';
                    }
                    return null;
                  } : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _autoSaveFrequency,
                  decoration: InputDecoration(
                    labelText: 'Frequency',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _autoSaveFrequency = value!;
                      if (value == 'weekly') {
                        _autoSaveDay = 1; // Monday
                      } else {
                        _autoSaveDay = 1; // 1st of month
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _autoSaveDay,
            decoration: InputDecoration(
              labelText: _autoSaveFrequency == 'weekly' ? 'Day of Week' : 'Day of Month',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            items: _autoSaveFrequency == 'weekly'
                ? const [
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                    DropdownMenuItem(value: 7, child: Text('Sunday')),
                  ]
                : List.generate(28, (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('${index + 1}${_getOrdinalSuffix(index + 1)}'),
                  )),
            onChanged: (value) {
              setState(() {
                _autoSaveDay = value!;
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

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _createVirtualBank,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Create Virtual Bank',
              style: TextStyle(
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

  Future<void> _createVirtualBank() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final targetAmount = double.parse(_targetAmountController.text.replaceAll(',', ''));
      final autoSaveAmount = _enableAutoSave 
          ? double.parse(_autoSaveAmountController.text.replaceAll(',', ''))
          : null;

      await context.read<FinanceProvider>().createVirtualBank(
        name: _nameController.text,
        targetAmount: targetAmount,
        color: _selectedColor,
        icon: _selectedIcon,
        description: _descriptionController.text.isEmpty 
            ? 'Savings goal for ${_nameController.text}'
            : _descriptionController.text,
        enableAutoSave: _enableAutoSave,
        autoSaveAmount: autoSaveAmount,
        autoSaveFrequency: _enableAutoSave ? _autoSaveFrequency : null,
        autoSaveDay: _enableAutoSave ? _autoSaveDay : null,
        type: _selectedType,
        debitSource: _selectedDebitSource ?? 'bank_account', // Provide default value
        targetDate: _targetDate,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Virtual Bank "${_nameController.text}" created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating virtual bank: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _descriptionController.dispose();
    _autoSaveAmountController.dispose();
    super.dispose();
  }
}

class IconOption {
  final String value;
  final IconData icon;
  final String label;

  IconOption(this.value, this.icon, this.label);
}

class ColorOption {
  final String value;
  final String label;

  ColorOption(this.value, this.label);
}