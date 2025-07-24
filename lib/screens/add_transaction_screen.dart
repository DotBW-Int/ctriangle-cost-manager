import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../core/providers/finance_provider.dart';
import '../core/models/models.dart';
import '../core/theme/app_theme.dart';

// Indian currency formatter class
class IndianCurrencyFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##,###', 'en_IN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters except decimal point
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Handle decimal point
    List<String> parts = digitsOnly.split('.');
    if (parts.length > 2) {
      // Multiple decimal points, keep only the first one
      digitsOnly = '${parts[0]}.${parts.sublist(1).join('')}';
      parts = digitsOnly.split('.');
    }
    
    // Format the integer part with Indian comma style
    String integerPart = parts[0];
    if (integerPart.isNotEmpty) {
      try {
        int number = int.parse(integerPart);
        integerPart = _formatter.format(number);
      } catch (e) {
        // If parsing fails, keep original
      }
    }
    
    // Reconstruct the number with decimal part if exists
    String formattedText = integerPart;
    if (parts.length == 2) {
      String decimalPart = parts[1];
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2); // Limit to 2 decimal places
      }
      formattedText += '.$decimalPart';
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class AddTransactionBottomSheet extends StatefulWidget {
  final String? initialType;

  const AddTransactionBottomSheet({
    super.key,
    this.initialType,
  });

  @override
  State<AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends State<AddTransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _customCategoryController = TextEditingController();
  
  String _selectedType = 'expense';
  String _selectedCategory = '';
  DateTime _selectedDate = DateTime.now();
  String? _receiptPath;
  String? _selectedVirtualBankId;
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  bool _isCreatingNewCategory = false;
  
  final ImagePicker _imagePicker = ImagePicker();
  late NumberFormat _currencyFormat;
  late String _currencySymbol;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? 'expense';
    _selectedCategory = _getDefaultCategory();
    _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize currency formatting based on user's locale
    _initializeCurrency();
  }

  void _initializeCurrency() {
    try {
      final locale = Localizations.localeOf(context);
      print('Detected locale: ${locale.toString()}');
      print('Country code: ${locale.countryCode}');
      print('Language code: ${locale.languageCode}');
      
      // Force India locale for testing - you can change this based on your preference
      final targetLocale = 'en_IN'; // Change this to your preferred locale
      
      // Get currency formatter for India locale
      _currencyFormat = NumberFormat.currency(locale: targetLocale);
      
      // Try to get the currency symbol more reliably
      final simpleCurrencyFormat = NumberFormat.simpleCurrency(locale: targetLocale);
      _currencySymbol = simpleCurrencyFormat.currencySymbol;
      
      print('Currency symbol from locale: $_currencySymbol');
      
      // Enhanced fallback logic with India-specific handling
      if (_currencySymbol.isEmpty || _currencySymbol == 'INR') {
        // Get currency based on target locale
        if (targetLocale.contains('IN') || targetLocale.contains('hi')) {
          _currencySymbol = '₹';
          _currencyFormat = NumberFormat.currency(locale: targetLocale, symbol: '₹');
        } else {
          // Try to extract from currency format pattern
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
              // Final fallback - detect by country or manual override
              _currencySymbol = '₹'; // Default to INR for you
          }
        }
      }
      
      print('Final currency symbol: $_currencySymbol');
    } catch (e) {
      print('Currency initialization error: $e');
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
        return '\$'; // Default fallback
    }
  }

  String _getDefaultCategory() {
    if (_selectedType == 'expense') {
      return FinanceProvider.expenseCategories.first;
    } else {
      return FinanceProvider.incomeCategories.first;
    }
  }

  List<String> _getCurrentCategories() {
    return _selectedType == 'expense' 
        ? FinanceProvider.expenseCategories 
        : FinanceProvider.incomeCategories;
  }

  @override
  Widget build(BuildContext context) {
    _initializeCurrency(); // Update currency format when rebuilding
    
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9, // Increased height
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 120, // Add keyboard padding
                ),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTypeSelector(),
                      const SizedBox(height: 20),
                      _buildAmountField(),
                      const SizedBox(height: 20),
                      _buildCategorySelector(),
                      const SizedBox(height: 20),
                      _buildDescriptionField(),
                      const SizedBox(height: 20),
                      _buildDatePicker(),
                      const SizedBox(height: 20),
                      _buildReceiptSection(),
                      if (_selectedType == 'expense') ...[
                        const SizedBox(height: 20),
                        _buildVirtualBankSelector(),
                      ],
                      const SizedBox(height: 20),
                      _buildRecurringSection(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Add ${_selectedType == 'expense' ? 'Expense' : 'Income'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption('expense', 'Expense', Icons.remove_circle, Colors.red),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeOption('income', 'Income', Icons.add_circle, Colors.green),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategory = _getDefaultCategory();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Theme.of(context).iconTheme.color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
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

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '$_currencySymbol ', // Use user's currency symbol
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          inputFormatters: [
            IndianCurrencyFormatter(), // Add Indian currency formatter only
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            // Remove commas before parsing
            final cleanValue = value.replaceAll(',', '');
            if (double.tryParse(cleanValue) == null) {
              return 'Please enter a valid amount';
            }
            if (double.parse(cleanValue) <= 0) {
              return 'Amount must be greater than 0';
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showCreateCategoryDialog(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isCreatingNewCategory)
          _buildNewCategoryField()
        else
          _buildCategoryDropdown(),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
      ),
      items: _getCurrentCategories().map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
        });
      },
    );
  }

  Widget _buildNewCategoryField() {
    return Column(
      children: [
        TextFormField(
          controller: _customCategoryController,
          decoration: InputDecoration(
            hintText: 'Enter new category name...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _saveNewCategory(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _cancelNewCategory(),
                ),
              ],
            ),
          ),
          validator: (value) {
            if (_isCreatingNewCategory && (value == null || value.isEmpty)) {
              return 'Please enter a category name';
            }
            return null;
          },
          onFieldSubmitted: (_) => _saveNewCategory(),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter a name for your new category and press the check mark to save',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            hintText: 'Enter description...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _dateController,
          readOnly: true,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onTap: _selectDate,
        ),
      ],
    );
  }

  Widget _buildReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Receipt (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickReceipt,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border.all(
                color: Theme.of(context).dividerColor,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  _receiptPath != null ? Icons.photo : Icons.camera_alt,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  _receiptPath != null ? 'Receipt Added' : 'Add Receipt Photo',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
        final virtualBanks = financeProvider.virtualBanks;
        
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
            DropdownButtonFormField<String?>(
              value: _selectedVirtualBankId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Main Balance'),
                ),
                ...virtualBanks.map((bank) {
                  return DropdownMenuItem<String?>(
                    value: bank.id,
                    child: Text('${bank.name} (\$${bank.balance.toStringAsFixed(2)})'),
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

  Widget _buildRecurringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value ?? false;
                });
              },
            ),
            Text(
              'Recurring Transaction',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _recurringFrequency,
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
              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
            ],
            onChanged: (value) {
              setState(() {
                _recurringFrequency = value!;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Add ${_selectedType == 'expense' ? 'Expense' : 'Income'}',
            onPressed: _saveTransaction,
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (image != null) {
        setState(() {
          _receiptPath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Remove commas before parsing the amount
    final cleanAmountText = _amountController.text.replaceAll(',', '');
    final amount = double.parse(cleanAmountText);
    final financeProvider = context.read<FinanceProvider>();

    // Check if paying from virtual bank and has sufficient balance
    if (_selectedVirtualBankId != null) {
      final virtualBank = financeProvider.virtualBanks
          .firstWhere((bank) => bank.id == _selectedVirtualBankId);
      if (virtualBank.balance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Insufficient balance in selected virtual bank'),
          ),
        );
        return;
      }
    }

    try {
      DateTime? nextDueDate;
      if (_isRecurring) {
        switch (_recurringFrequency) {
          case 'weekly':
            nextDueDate = _selectedDate.add(const Duration(days: 7));
            break;
          case 'monthly':
            nextDueDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
            break;
          case 'yearly':
            nextDueDate = DateTime(_selectedDate.year + 1, _selectedDate.month, _selectedDate.day);
            break;
        }
      }

      final transaction = Transaction(
        type: _isRecurring ? 'recurring' : _selectedType,
        amount: amount,
        category: _selectedCategory,
        description: _descriptionController.text,
        date: _selectedDate,
        receiptPath: _receiptPath,
        virtualBankId: _selectedVirtualBankId,
        isRecurring: _isRecurring,
        recurringFrequency: _isRecurring ? _recurringFrequency : null,
        nextDueDate: nextDueDate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await financeProvider.addTransaction(transaction);

      // If paying from virtual bank, deduct the amount
      if (_selectedVirtualBankId != null && _selectedType == 'expense') {
        await financeProvider.withdrawFromVirtualBank(_selectedVirtualBankId!, amount);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedType == 'expense' ? 'Expense' : 'Income'} added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCreateCategoryDialog() {
    setState(() {
      _isCreatingNewCategory = true;
      _customCategoryController.clear();
    });
  }

  void _saveNewCategory() {
    final newCategory = _customCategoryController.text.trim();
    if (newCategory.isNotEmpty) {
      final financeProvider = context.read<FinanceProvider>();
      
      // Add to the appropriate category list
      if (_selectedType == 'expense') {
        financeProvider.addExpenseCategory(newCategory);
      } else {
        financeProvider.addIncomeCategory(newCategory);
      }
      
      setState(() {
        _selectedCategory = newCategory;
        _isCreatingNewCategory = false;
        _customCategoryController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "$newCategory" added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _cancelNewCategory() {
    setState(() {
      _isCreatingNewCategory = false;
      _customCategoryController.clear();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }
}