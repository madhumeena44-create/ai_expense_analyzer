import 'package:flutter/material.dart';
import '../models/transaction_item.dart';
import 'ai_chat_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_expense_analyzer/services/sms_parser.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/financial_health_card.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Keeps track of the currently selected tab in the bottom navigation bar
  int _selectedTabIndex = 0;

  // Mutable state for transactions and balances
  List<TransactionItem> _transactions = [];
  double _totalBalance = 0.0;
  double _monthlyIncome = 0.0;
  double _monthlyExpenses = 0.0;
  double _baseMonthlySalary = 0.0; 
final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
// Profile settings state
  String _userName = 'Chaitanya Kumar';
  String _userEmail = 'chaitanya@example.com';
  String _userAvatarUrl = '';
  String _preferredCurrency = 'INR (₹)';
  bool _smartAlerts = true;
  bool _biometricEnabled = false;

  

Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar', pickedFile.path);
      setState(() {
        _userAvatarUrl = pickedFile.path;
      });
    }
  }
 void _recalculateTotals() {
    double additionalIncome = 0.0;
    double expenses = 0.0;

    for (var tx in _transactions) {
      if (tx.isIncome) {
        additionalIncome += tx.amount;
      } else {
        expenses += tx.amount;
      }
    }

    setState(() {
      _monthlyIncome = _baseMonthlySalary + additionalIncome;
      _monthlyExpenses = expenses;
      _totalBalance = (_baseMonthlySalary + additionalIncome) - expenses;
    });

    _saveTransactionsToStorage();
  }

    

Future<void> _saveTransactionsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = _transactions.map((tx) => jsonEncode(tx.toMap())).toList();
    await prefs.setStringList('saved_transactions', stringList);
  }

  Future<void> _loadTransactionsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = prefs.getStringList('saved_transactions');
    if (stringList != null && stringList.isNotEmpty) {
      setState(() {
        _transactions = stringList
            .map((item) => TransactionItem.fromMap(jsonDecode(item)))
            .toList();
            _userName = prefs.getString('profile_name') ?? 'Chaitanya Kumar';
        _userEmail = prefs.getString('profile_email') ?? 'chaitanya@example.com';
        _userAvatarUrl = prefs.getString('profile_avatar') ?? '';
        _preferredCurrency = prefs.getString('profile_currency') ?? 'INR (₹)';
        _smartAlerts = prefs.getBool('profile_alerts') ?? true;
        _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
        _baseMonthlySalary = prefs.getDouble('base_monthly_salary') ?? 0.0;
      });
      _recalculateTotals();
    }

  }
  @override
  void initState() {
    super.initState();
    _loadTransactionsFromStorage();
    _syncBankSms();
    
  }

  final SmsQuery _smsQuery = SmsQuery();
  
  Future<void> _syncBankSms() async {
    final permission = await Permission.sms.request();
    if (!permission.isGranted) return;
    

    try {
      final messages = await _smsQuery.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 50,
      );

      int addedCount = 0;

      for (var message in messages) {
        final body = message.body ?? '';
        final parsed = SmsParser.parse(body, message.date);

        if (parsed != null) {
          bool alreadyExists = _transactions.any((tx) =>
              tx.title.toLowerCase() == parsed.title.toLowerCase() &&
              tx.amount == parsed.amount &&
              tx.date.day == parsed.date.day &&
              tx.date.month == parsed.date.month);

          if (!alreadyExists) {
            _addNewTransaction(
              title: parsed.title,
              category: parsed.category,
              amount: parsed.amount,
              date: parsed.date,
              isIncome: parsed.isIncome,
            );
            addedCount++;
          }
        }
      }

      if (mounted && addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-synced $addedCount transactions from SMS!')),
        );
      }
    } catch (e) {
      debugPrint('Error reading SMS: $e');
    } 
  }

  /// Adds a new transaction and updates balances
  void _addNewTransaction({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    required bool isIncome,
  }) {
    final newTransaction = TransactionItem(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      amount: amount,
      date: date,
      isIncome: isIncome,
      icon: _getCategoryIcon(category, isIncome),
    );

    setState(() {
      _transactions.insert(0, newTransaction);
      globalTransactions.insert(0, newTransaction);
    });

    _recalculateTotals();
    
    _saveTransactionsToStorage();



    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${isIncome ? "Income" : "Expense"} of ₹${amount.toStringAsFixed(2)} added!'),
        backgroundColor: isIncome ? Colors.green.shade700 : Colors.teal.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
  }

 void _deleteTransaction(String id) {
    final existingIndex = _transactions.indexWhere((tx) => tx.id == id);
    if (existingIndex == -1) return;
    final deletedTx = _transactions[existingIndex];

    setState(() {
      _transactions.removeWhere((tx) => tx.id == id);
      _recalculateTotals();
    });

    _saveTransactionsToStorage();

    // Verification check in terminal
    print(">>> Deleted: ${deletedTx.title}. Showing SnackBar now...");

    // Floating SnackBar to avoid bottom navigation bar overlap
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Text('Deleted "${deletedTx.title}"'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.tealAccent,
          onPressed: () {
            setState(() {
              _transactions.insert(existingIndex, deletedTx);
              _recalculateTotals();
            });
            _saveTransactionsToStorage();
          },
        ),
      ),
    );
  }
  /// Category icon mapper
  IconData _getCategoryIcon(String category, bool isIncome) {
    if (isIncome) {
      switch (category) {
        case 'Salary':
          return Icons.account_balance;
        case 'Freelance':
          return Icons.work_outline;
        case 'Investment':
          return Icons.trending_up;
        default:
          return Icons.savings;
      }
    } else {
      switch (category) {
        case 'Food & Dining':
          return Icons.fastfood;
        case 'Shopping & Groceries':
          return Icons.shopping_bag;
        case 'Bills & Utilities':
          return Icons.receipt_long;
        case 'Travel & Transport':
          return Icons.directions_car;
        case 'Entertainment':
          return Icons.movie_outlined;
        case 'Health':
          return Icons.local_hospital_outlined;
        default:
          return Icons.payment;
      }
    }
  }

  /// Modal Bottom Sheet Form to Add a Transaction
  void _openAddTransactionModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    bool isIncome = false;
    DateTime selectedDate = DateTime.now();

    final expenseCategories = [
      'Food & Dining',
      'Shopping & Groceries',
      'Bills & Utilities',
      'Travel & Transport',
      'Entertainment',
      'Health',
      'Other',
    ];

    final incomeCategories = [
      'Salary',
      'Freelance',
      'Investment',
      'Gift / Bonus',
      'Other',
    ];

    String selectedCategory = expenseCategories.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeCategories = isIncome ? incomeCategories : expenseCategories;
            if (!activeCategories.contains(selectedCategory)) {
              selectedCategory = activeCategories.first;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header handle & title
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Transaction',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Income / Expense Toggle
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  isIncome = false;
                                  selectedCategory = expenseCategories.first;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !isIncome ? Colors.red.shade50 : Colors.transparent,
                                side: BorderSide(
                                  color: !isIncome ? Colors.red.shade700 : Colors.grey.shade300,
                                  width: !isIncome ? 2 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_upward,
                                color: !isIncome ? Colors.red.shade700 : Colors.grey,
                                size: 18,
                              ),
                              label: Text(
                                'Expense',
                                style: TextStyle(
                                  color: !isIncome ? Colors.red.shade700 : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  isIncome = true;
                                  selectedCategory = incomeCategories.first;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isIncome ? Colors.green.shade50 : Colors.transparent,
                                side: BorderSide(
                                  color: isIncome ? Colors.green.shade700 : Colors.grey.shade300,
                                  width: isIncome ? 2 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_downward,
                                color: isIncome ? Colors.green.shade700 : Colors.grey,
                                size: 18,
                              ),
                              label: Text(
                                'Income',
                                style: TextStyle(
                                  color: isIncome ? Colors.green.shade700 : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Amount Field
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '₹ ',
                          prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          hintText: '0.00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an amount';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Please enter a valid amount greater than 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        key: ValueKey(isIncome),
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(_getCategoryIcon(selectedCategory, isIncome), color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        items: activeCategories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedCategory = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Note / Description Field
                      TextFormField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Note / Title',
                          hintText: isIncome ? 'e.g. Monthly Salary, Freelance project' : 'e.g. Grocery store, Fuel toll',
                          prefixIcon: const Icon(Icons.edit_note, color: Colors.teal),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a note or title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date Picker Tile
                      InkWell(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: sheetContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null) {
                            setModalState(() {
                              selectedDate = pickedDate;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF9FAFB),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.teal),
                              const SizedBox(width: 12),
                              Text(
                                'Date: ${_formatDate(selectedDate)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Transaction Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              final amount = double.parse(amountController.text.trim());
                              final note = noteController.text.trim();

                              _addNewTransaction(
                                title: note,
                                amount: amount,
                                category: selectedCategory,
                                date: selectedDate,
                                isIncome: isIncome,
                              );

                              Navigator.pop(sheetContext);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Transaction',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

void _showEditSalaryDialog() {
    final controller = TextEditingController(text: _baseMonthlySalary.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Monthly Salary'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Monthly Salary / Income',
            prefixText: '$_preferredCurrency ',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('base_monthly_salary', val);
                setState(() {
                  _baseMonthlySalary = val;
                });
                _recalculateTotals();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      // 1. App Title & AppBar
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedTabIndex == 0
                  ? 'AI Expense Analyzer'
                  : _selectedTabIndex == 1
                      ? 'Spending Analytics'
                      : _selectedTabIndex == 2
                          ? 'Financial Advisor AI'
                          : _selectedTabIndex == 3
                              ? 'Transaction History'
                              : 'My Profile',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _selectedTabIndex == 0
                  ? 'Financial Overview'
                  : _selectedTabIndex == 1
                      ? 'Category Breakdown'
                      : _selectedTabIndex == 2
                          ? 'AI Chat Assistant'
                          : _selectedTabIndex == 3
                              ? 'All Past Records'
                              : 'Account Settings',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 28),
            tooltip: 'Add Transaction',
            onPressed: () => _openAddTransactionModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

     
      body: _selectedTabIndex == 1
          ? _buildAnalyticsView()
          : _selectedTabIndex == 2
              ? const AiChatScreen()
              : _selectedTabIndex == 3
                  ? _buildHistoryView()
                  : _selectedTabIndex == 4
                      ? _buildProfileView()
                      : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. Total Balance Card
            _buildTotalBalanceCard(),

            const SizedBox(height: 14),

            // 3 & 4. Monthly Income and Monthly Expenses Cards (Side-by-side)
            _buildIncomeAndExpenseCards(),

            const SizedBox(height: 20),

            // 7. AI Financial Insights Section
            _buildAiInsightsSection(),

            const SizedBox(height: 24),

            // 6. Spending by Category Section
            _buildCategorySpendingSection(),

            const SizedBox(height: 24),

            // 5. Recent Transactions Section
            _buildRecentTransactionsSection(),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // Floating '+' Action Button explicitly assigned to Scaffold.floatingActionButton
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        heroTag: 'main_add_transaction_fab',
        onPressed: () => _openAddTransactionModal(context),
        backgroundColor: const Color(0xFF00695C), // Distinct deep teal color
        foregroundColor: Colors.white,
        elevation: 6,
        tooltip: 'Add Transaction',
        shape: const CircleBorder(),
        child: const Icon(
          Icons.add,
          size: 32,
          color: Colors.white,
        ),
      ),

      // 8. Bottom Navigation Bar explicitly assigned to Scaffold.bottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (int index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.teal.shade800,
        unselectedItemColor: Colors.grey.shade600,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_outlined),
            activeIcon: Icon(Icons.document_scanner),
            label: 'Scan AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// 2. Widget: Total Balance Card
  Widget _buildTotalBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Balance',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'September 2026',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₹${_totalBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent.shade100, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Healthy savings buffer',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 3 & 4. Widget: Monthly Income & Monthly Expenses Side-by-Side Cards
  Widget _buildIncomeAndExpenseCards() {
    return Row(
      children: [
        // Monthly Income Card
        Expanded(
          child: GestureDetector(
            onTap: _showEditSalaryDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.green.shade50,
                      child: Icon(Icons.arrow_downward, color: Colors.green.shade700, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Income',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '+₹${_monthlyIncome.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('This Month', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Monthly Expenses Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
  radius: 14,
  backgroundColor: Colors.red.shade50,
  child: Icon(Icons.arrow_upward, color: Colors.red.shade700, size: 16),
),
                    const SizedBox(width: 8),
                    const Text(
                      'Expenses',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '-₹${_monthlyExpenses.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('This Month', style: TextStyle(fontSize: 11, color: Colors.grey)),
                
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 7. Widget: AI Financial Insights Section
  Widget _buildAiInsightsSection() {
    final insight = DummyData.insights.first;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.teal.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                insight.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'AI Powered',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            insight.description,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade800, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.tip,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Widget: Spending by Category Section
 Widget _buildCategorySpendingSection() {
    final Map<String, double> categoryTotals = {};
    for (var tx in _transactions) {
      if (!tx.isIncome) {
        categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0.0) + tx.amount;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Spending by Category',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTabIndex = 1;
                });
              },
              child: const Text(
                'View Breakdown',
                style: TextStyle(fontSize: 13, color: Color(0xFF00695C), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: categoryTotals.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No expenses recorded yet',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              : Column(
                  children: categoryTotals.entries.map((entry) {
                    final double maxSpent =
                        categoryTotals.values.reduce((a, b) => a > b ? a : b);
                    final double progress = maxSpent > 0 ? (entry.value / maxSpent) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '$_preferredCurrency${entry.value.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00695C)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
  /// 5. Widget: Recent Transactions Section
  Widget _buildRecentTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions (${_transactions.length})',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
           GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTabIndex = 3;
                  });
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
          child: _transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No transactions yet. Tap "+" to add one!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
              return Dismissible(
                key: Key(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.redAccent,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Transaction?'),
                      content: Text('Are you sure you want to delete "${tx.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  _deleteTransaction(tx.id);
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tx.isIncome ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(
                      tx.icon,
                      color: tx.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    tx.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${tx.category} • ${_formatDate(tx.date)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Text(
                    '${tx.isIncome ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: tx.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  


  /// Helper function to format DateTime into a user-friendly string
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.year == date.year && now.month == date.month && now.day == date.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }


Widget _buildProfileView() {
  final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Avatar with edit button
          Center(
            child: Stack(
              children: [
                CircleAvatar(
  radius: 45,
  backgroundColor: const Color(0xFFB2DFDB),
  backgroundImage: user?.photoURL != null
      ? NetworkImage(user!.photoURL!)
      : (_userAvatarUrl.isNotEmpty
          ? (_userAvatarUrl.startsWith('http')
              ? NetworkImage(_userAvatarUrl)
              : FileImage(File(_userAvatarUrl)) as ImageProvider)
          : null),
  child: (user?.photoURL == null && _userAvatarUrl.isEmpty)
      ? const Icon(Icons.person, size: 58, color: Color(0xFF00695C))
      : null,
),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: _pickImageFromGallery,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00695C),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
              user?.displayName?.isNotEmpty == true ? user!.displayName! : _userName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 16, color: Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
          user?.email ?? _userEmail,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
          const SizedBox(height: 28),
          const FinancialHealthCard(
              score: 84,
              monthlyBudget: 25000,
              currentSpend: 14320,
              consecutiveLogDays: 12,
            ),
            const SizedBox(height: 16),


          // Settings Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7FBF9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_rupee, color: Color(0xFF00695C)),
                  title: const Text('Preferred Currency', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Text(
                    _preferredCurrency,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  onTap: _showCurrencyDialog,
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                SwitchListTile(
                  secondary: const Icon(Icons.notifications_none, color: Color(0xFF00695C)),
                  title: const Text('Smart Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
                  value: _smartAlerts,
                  activeColor: const Color(0xFF00695C),
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('profile_alerts', val);
                    setState(() => _smartAlerts = val);
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Color(0xFF00695C)),
                  title: const Text('Security & Privacy', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _showSecurityPrivacyDialog,
                ),
                Divider(height: 1, color: Colors.grey.shade200),

                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF00695C)),
                  title: const Text('Export Records (CSV)', style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _exportRecordsToCsv,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          TextButton.icon(
            onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            label: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _userEmail);
    final avatarCtrl = TextEditingController(text: _userAvatarUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avatarCtrl,
              decoration: const InputDecoration(
                labelText: 'Profile Image URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('profile_name', nameCtrl.text.trim());
              await prefs.setString('profile_email', emailCtrl.text.trim());
              await prefs.setString('profile_avatar', avatarCtrl.text.trim());
              setState(() {
                _userName = nameCtrl.text.trim();
                _userEmail = emailCtrl.text.trim();
                _userAvatarUrl = avatarCtrl.text.trim();
              });
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog() {
    final currencies = ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AED (د.إ)'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Select Preferred Currency', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...currencies.map((curr) => ListTile(
              title: Text(curr),
              trailing: _preferredCurrency == curr
                  ? const Icon(Icons.check_circle, color: Color(0xFF00695C))
                  : null,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('profile_currency', curr);
                setState(() => _preferredCurrency = curr);
                if (mounted) Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showSecurityPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Security & Privacy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Biometric / App Lock'),
                subtitle: const Text('Require fingerprint to open'),
                value: _biometricEnabled,
                activeColor: const Color(0xFF00695C),
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('profile_biometrics', val);
                  setDialogState(() => _biometricEnabled = val);
                  setState(() => _biometricEnabled = val);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Clear All Local Cache'),
                trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('saved_transactions');
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transactions cache cleared')),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _exportRecordsToCsv() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Title,Category,Amount,Type,Date');
    for (var tx in _transactions) {
      buffer.writeln(
        '${tx.id},"${tx.title}","${tx.category}",${tx.amount},${tx.isIncome ? "Income" : "Expense"},${tx.date.toIso8601String()}',
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Export Records (CSV)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              buffer.toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
Widget _buildAnalyticsView() {
    final expenseTransactions =
        _transactions.where((tx) => !tx.isIncome).toList();

    if (expenseTransactions.isEmpty) {
      return const Center(
        child: Text(
          'No expense data to analyze yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final Map<String, double> categoryTotals = {};
    for (final tx in expenseTransactions) {
      categoryTotals[tx.category] =
          (categoryTotals[tx.category] ?? 0) + tx.amount;
    }

    final totalExpense =
        categoryTotals.values.fold(0.0, (sum, val) => sum + val);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            color: Colors.green.shade50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Expenses',
                        style: TextStyle(
                            fontSize: 14, color: Colors.green.shade900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '₹${totalExpense.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.pie_chart, size: 40, color: Colors.green.shade700),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Spending by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...categoryTotals.entries.map((entry) {
            final percentage =
                totalExpense > 0 ? (entry.value / totalExpense) : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '₹${entry.value.toStringAsFixed(2)} (${(percentage * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.teal,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

Widget _buildHistoryView() {
    final filteredTransactions = _transactions.where((tx) {
      final query = _searchQuery.toLowerCase();
      return tx.title.toLowerCase().contains(query) ||
          tx.category.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by title or category...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: filteredTransactions.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No transactions logged yet.'
                        : 'No results found for "$_searchQuery"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: filteredTransactions.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                final tx = filteredTransactions[index];
                return Dismissible(
                  key: Key(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Transaction?'),
                        content: Text('Are you sure you want to delete "${tx.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    _deleteTransaction(tx.id);
                  },
                  child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              tx.isIncome ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            tx.icon,
                            color: tx.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${tx.category} • ${tx.date.day}/${tx.date.month}/${tx.date.year}'),
                        trailing: Text(
                          '${tx.isIncome ? "+" : "-"}₹${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color:
                                tx.isIncome ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

}
