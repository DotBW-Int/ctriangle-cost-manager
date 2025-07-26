import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:io';
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
  final Transaction? editTransaction; // Add support for editing existing transactions
  final String? initialType;

  const AddTransactionBottomSheet({
    super.key,
    this.editTransaction,
    this.initialType,
  });

  @override
  State<AddTransactionBottomSheet> createState() => _AddTransactionBottomSheetState();
}

class _AddTransactionBottomSheetState extends State<AddTransactionBottomSheet>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _customCategoryController = TextEditingController();
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
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
  bool _isEditing = false;
  Transaction? _originalTransaction;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Check if we're editing an existing transaction
    if (widget.editTransaction != null) {
      _isEditing = true;
      _originalTransaction = widget.editTransaction;
      _loadTransactionData(widget.editTransaction!);
    } else {
      _selectedType = widget.initialType ?? 'expense';
      _selectedCategory = '';
    }
    
    _dateController.text = DateFormat('MMM dd, yyyy').format(_selectedDate);
    
    // Initialize animations
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    Future.delayed(const Duration(milliseconds: 100), () {
      _slideController.forward();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
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

  void _loadTransactionData(Transaction transaction) {
    _selectedType = transaction.type;
    _amountController.text = transaction.amount.toString();
    _selectedCategory = transaction.category;
    _descriptionController.text = transaction.description;
    _selectedDate = transaction.date;
    _receiptPath = transaction.receiptPath;
    _selectedVirtualBankId = transaction.virtualBankId;
    _isRecurring = transaction.isRecurring;
    _recurringFrequency = transaction.recurringFrequency ?? 'monthly';
    _recurringEndDate = transaction.nextDueDate;
  }

  @override
  Widget build(BuildContext context) {
    _initializeCurrency();
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, (1 - _slideAnimation.value) * 100),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.95,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildEnhancedHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 24,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                      ),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEnhancedTypeSelector(),
                              const SizedBox(height: 28),
                              _buildEnhancedAmountField(),
                              const SizedBox(height: 28),
                              _buildEnhancedCategoryField(),
                              const SizedBox(height: 28),
                              _buildEnhancedDescriptionField(),
                              const SizedBox(height: 28),
                              _buildEnhancedDatePicker(),
                              const SizedBox(height: 28),
                              _buildEnhancedReceiptSection(),
                              if (_selectedType == 'expense') ...[
                                const SizedBox(height: 28),
                                _buildEnhancedVirtualBankSelector(),
                              ],
                              const SizedBox(height: 28),
                              _buildEnhancedRecurringSection(),
                              const SizedBox(height: 32),
                              _buildActionButtons(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Enhanced header with floating close button
          Stack(
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _selectedType == 'income' ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add Transaction',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecurring 
                          ? 'Set up recurring ${_selectedType}'
                          : 'Track your ${_selectedType == 'expense' ? 'expenses' : 'income'} effortlessly',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Enhanced progress indicator with animation
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * _getFormProgress() * 0.85,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Colors.white70],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
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
    return progress.clamp(0.2, 1.0);
  }

  Widget _buildEnhancedTypeSelector() {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildEnhancedTypeOption('expense', 'Expense', Icons.trending_down_rounded, Colors.red),
          ),
          Expanded(
            child: _buildEnhancedTypeOption('income', 'Income', Icons.trending_up_rounded, Colors.green),
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
          _selectedVirtualBankId = null;
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: color, width: 2) : null,
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Container(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? color : Theme.of(context).iconTheme.color?.withOpacity(0.7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildEnhancedAmountField() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).cardColor.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _amountController.text.isNotEmpty 
              ? AppTheme.primaryBlue.withOpacity(0.6)
              : Theme.of(context).dividerColor.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _amountController.text.isNotEmpty 
                ? AppTheme.primaryBlue.withOpacity(0.15)
                : Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _selectedType == 'income'
                        ? LinearGradient(
                            colors: [Colors.green.shade600, Colors.green.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.red.shade600, Colors.red.shade400],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedType == 'income' ? Colors.green : Colors.red).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _selectedType == 'income' 
                        ? Icons.trending_up_rounded 
                        : Icons.trending_down_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleMedium?.color,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter the ${_selectedType == 'income' ? "income" : "expense"} amount',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_amountController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          (_selectedType == 'income' ? Colors.green : Colors.red).withOpacity(0.2),
                          (_selectedType == 'income' ? Colors.green : Colors.red).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '₹${_amountController.text}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedType == 'income' ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Amount input field
          Container(
            margin: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _amountController.text.isNotEmpty 
                    ? (_selectedType == 'income' ? Colors.green : Colors.red).withOpacity(0.5)
                    : Theme.of(context).dividerColor.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _amountController.text.isNotEmpty 
                    ? (_selectedType == 'income' ? Colors.green : Colors.red)
                    : Theme.of(context).textTheme.bodyLarge?.color,
                letterSpacing: 0.5,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  fontSize: 20,
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (_selectedType == 'income' ? Colors.green : Colors.red).withOpacity(0.2),
                        (_selectedType == 'income' ? Colors.green : Colors.red).withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '₹',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _selectedType == 'income' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (double.parse(value) <= 0) {
                  return 'Amount must be greater than 0';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {});
                HapticFeedback.selectionClick();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSaveButton() {
    bool isFormValid = _formKey.currentState?.validate() ?? false;
    bool hasRequiredFields = _amountController.text.isNotEmpty && _selectedCategory.isNotEmpty;
    
    return Container(
      width: double.infinity,
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: hasRequiredFields
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                    Colors.blue.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Theme.of(context).dividerColor.withOpacity(0.3),
                    Theme.of(context).dividerColor.withOpacity(0.2),
                  ],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: hasRequiredFields ? [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: hasRequiredFields ? () {
              HapticFeedback.mediumImpact();
              _saveTransaction();
            } : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(right: 12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasRequiredFields ? Colors.white : Theme.of(context).disabledColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: hasRequiredFields 
                            ? Colors.white.withOpacity(0.2)
                            : Theme.of(context).disabledColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.save_rounded,
                        color: hasRequiredFields ? Colors.white : Theme.of(context).disabledColor,
                        size: 20,
                      ),
                    ),
                  Text(
                    _isLoading ? 'Saving Transaction...' : 'Save Transaction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasRequiredFields ? Colors.white : Theme.of(context).disabledColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() => _isLoading = true);

      final financeProvider = context.read<FinanceProvider>();
      final amount = double.parse(_amountController.text.replaceAll(',', ''));
      
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

      if (_isEditing && _originalTransaction != null) {
        // Update existing transaction
        final updatedTransaction = _originalTransaction!.copyWith(
          type: _selectedType,
          amount: amount,
          category: _selectedCategory,
          description: _descriptionController.text,
          date: _selectedDate,
          receiptPath: _receiptPath,
          virtualBankId: _selectedVirtualBankId,
          isRecurring: _isRecurring,
          recurringFrequency: _isRecurring ? _recurringFrequency : null,
          nextDueDate: nextDueDate,
          updatedAt: DateTime.now(),
          editHistory: [
            ...(_originalTransaction!.editHistory ?? []),
            {
              'timestamp': DateTime.now(),
              'description': 'Amount changed from ${_currencyFormat.format(_originalTransaction!.amount)} to ${_currencyFormat.format(amount)}',
              'oldAmount': _originalTransaction!.amount,
              'newAmount': amount,
            }
          ],
        );

        await financeProvider.updateTransaction(updatedTransaction);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaction updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new transaction
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

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedType == 'expense' ? 'Expense' : 'Income'} added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Add missing build methods for other form fields
  Widget _buildEnhancedCategoryField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DropdownButtonFormField<String>(
              value: _selectedCategory.isNotEmpty ? _selectedCategory : null,
              decoration: InputDecoration(
                hintText: 'Select category',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: _getCurrentCategories().map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value ?? '';
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEnhancedDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Enter description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEnhancedDatePicker() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Date',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Select date',
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                    _dateController.text = DateFormat('MMM dd, yyyy').format(date);
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEnhancedReceiptSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            if (_receiptPath != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt),
                  title: const Text('Receipt attached'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => _receiptPath = null),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedVirtualBankSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Virtual Bank (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            Consumer<FinanceProvider>(
              builder: (context, financeProvider, child) {
                final virtualBanks = financeProvider.virtualBanks;
                return DropdownButtonFormField<String>(
                  value: _selectedVirtualBankId,
                  decoration: InputDecoration(
                    hintText: 'Select virtual bank',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ...virtualBanks.map((bank) {
                      return DropdownMenuItem(value: bank.id, child: Text(bank.name));
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedVirtualBankId = value;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedRecurringSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recurring Transaction',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleMedium?.color,
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
              DropdownButtonFormField<String>(
                value: _recurringFrequency,
                decoration: InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildEnhancedSaveButton(),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _receiptPath = image.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}