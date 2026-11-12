import 'package:flutter/material.dart';

class FinancialHealthCard extends StatelessWidget {
  final int score;
  final double monthlyBudget;
  final double currentSpend;
  final int consecutiveLogDays;

  const FinancialHealthCard({
    super.key,
    this.score = 82,
    this.monthlyBudget = 25000,
    this.currentSpend = 14320,
    this.consecutiveLogDays = 12,
  });

  String get _healthGrade {
    if (score >= 80) return 'Prudent Saver';
    if (score >= 60) return 'Balanced';
    if (score >= 40) return 'Needs Attention';
    return 'Overspending Alert';
  }

  Color get _healthColor {
    if (score >= 80) return const Color(0xFF00A86B);
    if (score >= 60) return const Color(0xFFFFB300);
    return const Color(0xFFE53935);
  }

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: _healthColor),
                const SizedBox(width: 8),
                const Text(
                  'Health Score Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _metricRow('Budget Discipline', '57% used (On Track)', Icons.pie_chart, Colors.teal),
            _metricRow('Receipt Audit Frequency', '$consecutiveLogDays-day streak', Icons.document_scanner, Colors.blueAccent),
            _metricRow('Discretionary Ratio', 'Down 8% vs last week', Icons.trending_down, Colors.greenAccent),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF00A86B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gemini Tip: Dining expenses make up 34% of your discretionary spending this month.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static Widget _metricRow(String title, String val, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 5,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(_healthColor),
                    ),
                  ),
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E222A),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          _healthGrade,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _healthColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _healthColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'AI Audited',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${currentSpend.toInt()} spent of ₹${monthlyBudget.toInt()}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onPressed: () => _showBreakdown(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBadge('🛡️ 7d Streak', 'Consistent'),
              _buildBadge('📉 -12%', 'Lower Spend'),
              _buildBadge('🎯 43% Saved', 'Safe Margin'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1E222A)),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}
