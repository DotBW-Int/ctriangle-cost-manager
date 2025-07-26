import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

// Indian currency formatter
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
    
    // Remove any non-digit characters except decimal point
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    
    // Handle decimal point
    List<String> parts = [];
    if (digitsOnly.contains('.')) {
      parts = digitsOnly.split('.');
    }
    
    // Format the integer part with Indian comma style
    String integerPart = parts.isEmpty ? digitsOnly : parts[0];
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
  
  // Enhanced recurring options
  DateTime? _recurringEndDate;
  int? _recurringCount;
  bool _hasEndCondition = false;
  String _endConditionType = 'never'; // 'never', 'date', 'count'
  
  final ImagePicker _imagePicker = ImagePicker();
  late NumberFormat _currencyFormat;
  late String _currencySymbol;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? 'expense';
    // Remove default category - let user select
    _selectedCategory = '';
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
              // Final fallback - default to INR for India
              _currencySymbol = '₹';
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
    final categories = _getCurrentCategories();
    if (categories.isNotEmpty) {
      return categories.first;
    }
    return '';
  }

  List<String> _getCurrentCategories() {
    return _selectedType == 'expense' 
        ? FinanceProvider.expenseCategories 
        : FinanceProvider.incomeCategories;
  }

  @override
  Widget build(BuildContext context) {
    _initializeCurrency();
    
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.95, // Increased height for more content
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildEnhancedHeader(),
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
                      _buildEnhancedTypeSelector(),
                      const SizedBox(height: 24),
                      _buildEnhancedAmountField(),
                      const SizedBox(height: 24),
                      _buildCategorySelector(),
                      const SizedBox(height: 24),
                      _buildDescriptionField(),
                      const SizedBox(height: 24),
                      _buildDatePicker(),
                      const SizedBox(height: 24),
                      _buildEnhancedReceiptSection(),
                      if (_selectedType == 'expense') ...[
                        const SizedBox(height: 24),
                        _buildEnhancedVirtualBankSelector(),
                      ],
                      const SizedBox(height: 24),
                      _buildEnhancedRecurringSection(),
                      const SizedBox(height: 30),
                      _buildActionButton(),
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

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Add Transaction',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).cardColor,
              foregroundColor: Theme.of(context).iconTheme.color,
            ),
          ),
        ],
      ),
    );
  }

  double _getFormProgress() {
    double progress = 0.0;
    if (_amountController.text.isNotEmpty) progress += 0.3;
    if (_selectedCategory.isNotEmpty) progress += 0.2;
    if (_descriptionController.text.isNotEmpty) progress += 0.2;
    if (_receiptPath != null) progress += 0.1;
    if (_isRecurring) progress += 0.1;
    if (_selectedVirtualBankId != null && _selectedType == 'expense') progress += 0.1;
    return progress.clamp(0.2, 1.0); // Minimum 20% to show some progress
  }

  Widget _buildEnhancedTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildEnhancedTypeOption('expense', 'Expense', Icons.trending_down, Colors.red),
          ),
          Expanded(
            child: _buildEnhancedTypeOption('income', 'Income', Icons.trending_up, Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTypeOption(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _selectedCategory = _getDefaultCategory();
          _selectedVirtualBankId = null; // Reset virtual bank when switching type
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Theme.of(context).iconTheme.color,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.attach_money,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Amount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _selectedType == 'expense' ? Colors.red : Colors.green,
            ),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixText: '$_currencySymbol ',
              prefixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _selectedType == 'expense' ? Colors.red : Colors.green,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.all(20),
            ),
            inputFormatters: [IndianCurrencyFormatter()],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
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
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                    dropdownColor: _isDarkMode ? Colors.grey[800] : Colors.white,
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: IconButton(
                onPressed: _showAddCategoryDialog,
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).primaryColor,
                ),
                tooltip: 'Add New Category',
              ),
            ),
          ],
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
            hintText: 'Enter transaction details',
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

  Widget _buildEnhancedReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.receipt,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Receipt (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_receiptPath != null) 
          _buildReceiptPreview()
        else
          _buildReceiptOptions(),
      ],
    );
  }

  Widget _buildReceiptPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(File(_receiptPath!)),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt Added',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to change or remove',
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showReceiptPreview(),
                icon: const Icon(Icons.visibility),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.2),
                  foregroundColor: Colors.green,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _receiptPath = null),
                icon: const Icon(Icons.delete),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptOptions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _pickReceipt(ImageSource.camera),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Camera',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _pickReceipt(ImageSource.gallery),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gallery',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedVirtualBankSelector() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        final virtualBanks = financeProvider.virtualBanks.where((bank) => bank.balance > 0).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Payment Source',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                children: [
                  _buildPaymentOption(
                    null,
                    'Main Balance',
                    _currencyFormat.format(financeProvider.totalBalance),
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                  ...virtualBanks.map((bank) => _buildPaymentOption(
                    bank.id,
                    bank.name,
                    _currencyFormat.format(bank.balance),
                    _getVirtualBankIcon(bank.icon),
                    Color(int.parse(bank.color.replaceFirst('#', '0xFF'))),
                  )),
                ],
              ),
            ),
            if (_selectedVirtualBankId != null) ...[
              const SizedBox(height: 12),
              _buildVirtualBankInfo(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPaymentOption(String? bankId, String name, String balance, IconData icon, Color color) {
    final isSelected = _selectedVirtualBankId == bankId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVirtualBankId = bankId;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    'Balance: $balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualBankInfo() {
    return Consumer<FinanceProvider>(
      builder: (context, financeProvider, child) {
        final bank = financeProvider.virtualBanks
            .where((b) => b.id == _selectedVirtualBankId)
            .firstOrNull;
        
        if (bank == null) return const SizedBox.shrink();
        
        final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
        final insufficientFunds = amount > bank.balance;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: insufficientFunds ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: insufficientFunds ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    insufficientFunds ? Icons.warning : Icons.info,
                    color: insufficientFunds ? Colors.red : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    insufficientFunds ? 'Insufficient Funds' : 'Payment Info',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: insufficientFunds ? Colors.red : Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Available Balance:'),
                  Text(
                    _currencyFormat.format(bank.balance),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (amount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Transaction Amount:'),
                    Text(
                      _currencyFormat.format(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: insufficientFunds ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Remaining Balance:'),
                    Text(
                      _currencyFormat.format((bank.balance - amount).clamp(0, double.infinity)),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: insufficientFunds ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhancedRecurringSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRecurring ? Colors.orange.withOpacity(0.1) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRecurring ? Colors.orange.withOpacity(0.3) : Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.repeat,
                color: _isRecurring ? Colors.orange : Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recurring Transaction',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isRecurring ? Colors.orange : null,
                  ),
                ),
              ),
              Switch(
                value: _isRecurring,
                onChanged: (value) {
                  setState(() {
                    _isRecurring = value;
                  });
                },
              ),
            ],
          ),
          if (_isRecurring) ...[
            const SizedBox(height: 16),
            Text(
              'Frequency',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _recurringFrequency,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
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
            const SizedBox(height: 16),
            Text(
              'End Condition',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Never'),
                    value: 'never',
                    groupValue: _endConditionType,
                    onChanged: (value) {
                      setState(() {
                        _endConditionType = value!;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('End Date'),
                    value: 'date',
                    groupValue: _endConditionType,
                    onChanged: (value) {
                      setState(() {
                        _endConditionType = value!;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (_endConditionType == 'date') ...[
              const SizedBox(height: 8),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'End Date',
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                controller: TextEditingController(
                  text: _recurringEndDate != null 
                      ? DateFormat('MMM dd, yyyy').format(_recurringEndDate!)
                      : '',
                ),
                onTap: _selectRecurringEndDate,
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[700],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This transaction will repeat automatically ${_getRecurringDescription()}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getRecurringDescription() {
    String desc = _recurringFrequency;
    if (_endConditionType == 'date' && _recurringEndDate != null) {
      desc += ' until ${DateFormat('MMM dd, yyyy').format(_recurringEndDate!)}';
    } else {
      desc += ' indefinitely';
    }
    return desc;
  }

  IconData _getVirtualBankIcon(String iconName) {
    switch (iconName) {
      case 'savings': return Icons.savings;
      case 'home': return Icons.home;
      case 'car': return Icons.directions_car;
      case 'flight': return Icons.flight;
      case 'security': return Icons.security;
      case 'school': return Icons.school;
      case 'medical': return Icons.medical_services;
      case 'shopping': return Icons.shopping_bag;
      case 'entertainment': return Icons.movie;
      case 'food': return Icons.restaurant;
      case 'gym': return Icons.fitness_center;
      case 'business': return Icons.business;
      case 'investment': return Icons.trending_up;
      case 'charity': return Icons.volunteer_activism;
      default: return Icons.account_balance;
    }
  }

  void _showReceiptPreview() {
    if (_receiptPath == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Receipt Preview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: Image.file(
                File(_receiptPath!),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final isExpense = _selectedType == 'expense';
    final buttonColor = isExpense ? Colors.red : Colors.green;
    
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(top: 24),
      child: ElevatedButton(
        onPressed: _saveTransaction,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Add ${isExpense ? 'Expense' : 'Income'}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final cleanAmountText = _amountController.text.replaceAll(',', '');
    final amount = double.parse(cleanAmountText);
    final financeProvider = context.read<FinanceProvider>();

    // Enhanced validation for virtual bank
    if (_selectedVirtualBankId != null) {
      final virtualBank = financeProvider.virtualBanks
          .where((bank) => bank.id == _selectedVirtualBankId)
          .firstOrNull;
      if (virtualBank != null && virtualBank.balance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient balance in ${virtualBank.name}. Available: ${_currencyFormat.format(virtualBank.balance)}'),
            backgroundColor: Colors.red,
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
      
      // Add to the appropriate category
      if (_selectedType == 'expense') {
        FinanceProvider.expenseCategories.add(newCategory);
      } else {
        FinanceProvider.incomeCategories.add(newCategory);
      }
      
      setState(() {
        _selectedCategory = newCategory;
        _isCreatingNewCategory = false;
      });
      
      // Optionally, save to persistent storage or backend
      // financeProvider.saveCategory(newCategory, _selectedType);
    }
  }

  void _pickReceipt(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        setState(() {
          _receiptPath = pickedFile.path;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _selectDate() async {
    final initialDate = _selectedDate;
    final firstDate = DateTime(initialDate.year - 5);
    final lastDate = DateTime(initialDate.year + 5);
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              secondary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _selectRecurringEndDate() async {
    final initialDate = _recurringEndDate ?? DateTime.now().add(const Duration(days: 30));
    final firstDate = DateTime.now();
    final lastDate = DateTime(initialDate.year + 10);
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null) {
      setState(() {
        _recurringEndDate = pickedDate;
      });
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customCategoryController,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'Enter category name',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveNewCategory();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;

  List<String> get _categories {
    final categories = _getCurrentCategories();
    return categories.isNotEmpty ? categories : ['Other'];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }
}