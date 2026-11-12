class ParsedBankTx {
  final double amount;
  final String title;
  final String category;
  final bool isIncome;
  final DateTime date;

  ParsedBankTx({
    required this.amount,
    required this.title,
    required this.category,
    required this.isIncome,
    required this.date,
  });
}

class SmsParser {
  static final RegExp debitRegex = RegExp(r'(?:debited|spent|paid|dr\b|sent\s+to)', caseSensitive: false);
  static final RegExp creditRegex = RegExp(r'(?:credited|received|deposited|cr\b|added)', caseSensitive: false);
  static final RegExp amountRegex = RegExp(r'(?:rs\.?|inr)\s*([\d,]+\.?\d*)', caseSensitive: false);
  static final RegExp vendorRegex = RegExp(r'(?:to|at|vpa|info)\s+([a-zA-Z0-9\s]+?)(?:\.|\s+on|\s+ref|\s+upi|\s+avl|\s+bal)', caseSensitive: false);

  static ParsedBankTx? parse(String messageBody, DateTime? date) {
    final bool isDebit = debitRegex.hasMatch(messageBody);
    final bool isCredit = creditRegex.hasMatch(messageBody);

    if (!isDebit && !isCredit) return null;

    final match = amountRegex.firstMatch(messageBody);
    if (match == null) return null;

    String cleanAmount = match.group(1)!.replaceAll(',', '');
    double? parsedAmount = double.tryParse(cleanAmount);
    if (parsedAmount == null || parsedAmount <= 0) return null;

    String title = isCredit ? "Received Payment" : "UPI Payment";
    final vendorMatch = vendorRegex.firstMatch(messageBody);
    if (vendorMatch != null && vendorMatch.group(1) != null) {
      final name = vendorMatch.group(1)!.trim();
      if (name.isNotEmpty && name.length < 30) {
        title = name;
      }
    }

    String category = _detectCategory('$messageBody $title');

    return ParsedBankTx(
      amount: parsedAmount,
      title: title,
      category: category,
      isIncome: isCredit,
      date: date ?? DateTime.now(),
    );
  }

  static String _detectCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('swiggy') || lower.contains('zomato') || lower.contains('restaurant') || lower.contains('food') || lower.contains('bakery') || lower.contains('cafe')) {
      return 'Food & Dining';
    } else if (lower.contains('uber') || lower.contains('ola') || lower.contains('fuel') || lower.contains('petrol') || lower.contains('irctc') || lower.contains('travel')) {
      return 'Travel & Transport';
    } else if (lower.contains('amazon') || lower.contains('flipkart') || lower.contains('myntra') || lower.contains('mart')) {
      return 'Shopping';
    } else if (lower.contains('recharge') || lower.contains('bill') || lower.contains('electricity') || lower.contains('jio') || lower.contains('airtel')) {
      return 'Bills & Utilities';
    } else if (lower.contains('dividend') || lower.contains('interest') || lower.contains('salary') || lower.contains('bonus')) {
      return 'Income';
    }
    return 'Other';
  }
}