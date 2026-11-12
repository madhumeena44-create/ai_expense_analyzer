import 'package:flutter/material.dart';

/// Represents a single financial transaction (Income or Expense).
class TransactionItem {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final bool isIncome;
  final IconData icon;

  const TransactionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.isIncome,
    required this.icon,
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
      'isIncome': isIncome,
      'iconCode': icon.codePoint,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'General',
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      isIncome: map['isIncome'] ?? false,
      icon: _resolveIcon(map['category']),
    );
  }

  static IconData _resolveIcon(String? category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Shopping & Groceries':
        return Icons.shopping_bag;
      case 'Bills & Utilities':
        return Icons.receipt_long;
      case 'Travel & Transport':
        return Icons.directions_car;
      case 'Entertainment':
        return Icons.movie;
      case 'Salary':
        return Icons.account_balance_wallet;
      case 'Freelance':
        return Icons.laptop;
      default:
        return Icons.attach_money;
    }
  }

}

/// Represents spending in a specific category for progress bars.
class CategorySpending {
  final String name;
  final double amount;
  final double progress; // Value between 0.0 and 1.0 for the progress bar
  final IconData icon;
  final Color color;

  const CategorySpending({
    required this.name,
    required this.amount,
    required this.progress,
    required this.icon,
    required this.color,
  });
}

/// Represents an AI-generated financial tip or spending insight.
class AiInsight {
  final String title;
  final String description;
  final String tip;
  final IconData icon;

  const AiInsight({
    required this.title,
    required this.description,
    required this.tip,
    required this.icon,
  });
}

/// Dummy data used to populate the dashboard before connecting a real database.
class DummyData {
  static const double totalBalance = 45850.00;
  static const double monthlyIncome = 75000.00;
  static const double monthlyExpenses = 29150.00;

  static final List<TransactionItem> recentTransactions = [
    TransactionItem(
      id: 'tx_1',
      title: 'Salary Deposit',
      category: 'Income',
      amount: 75000.00,
      date: DateTime.now().subtract(const Duration(days: 1)),
      isIncome: true,
      icon: Icons.account_balance,
    ),
    TransactionItem(
      id: 'tx_2',
      title: 'Supermarket Groceries',
      category: 'Groceries',
      amount: 3250.00,
      date: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      isIncome: false,
      icon: Icons.shopping_cart,
    ),
    TransactionItem(
      id: 'tx_3',
      title: 'Electricity & Water Bill',
      category: 'Utilities',
      amount: 1840.00,
      date: DateTime.now().subtract(const Duration(days: 2)),
      isIncome: false,
      icon: Icons.bolt,
    ),
    TransactionItem(
      id: 'tx_4',
      title: 'Restaurant Dinner',
      category: 'Dining',
      amount: 1450.00,
      date: DateTime.now().subtract(const Duration(days: 3)),
      isIncome: false,
      icon: Icons.restaurant,
    ),
    TransactionItem(
      id: 'tx_5',
      title: 'Freelance Design Project',
      category: 'Side Income',
      amount: 12000.00,
      date: DateTime.now().subtract(const Duration(days: 4)),
      isIncome: true,
      icon: Icons.work_outline,
    ),
  ];

  static const List<CategorySpending> categories = [
    CategorySpending(
      name: 'Food & Dining',
      amount: 8650.00,
      progress: 0.65,
      icon: Icons.fastfood,
      color: Colors.orange,
    ),
    CategorySpending(
      name: 'Shopping & Groceries',
      amount: 6200.00,
      progress: 0.45,
      icon: Icons.shopping_bag,
      color: Colors.blue,
    ),
    CategorySpending(
      name: 'Bills & Utilities',
      amount: 4800.00,
      progress: 0.35,
      icon: Icons.receipt_long,
      color: Colors.deepPurple,
    ),
    CategorySpending(
      name: 'Travel & Transport',
      amount: 2950.00,
      progress: 0.22,
      icon: Icons.directions_car,
      color: Colors.teal,
    ),
  ];

  static const List<AiInsight> insights = [
    AiInsight(
      title: 'Smart Spending Alert',
      description: 'Your dining expenses decreased by 18% compared to last week.',
      tip: 'You can allocate an extra ₹2,500 toward your monthly savings target.',
      icon: Icons.auto_awesome,
    ),
  ];
}
List<TransactionItem> globalTransactions = [];