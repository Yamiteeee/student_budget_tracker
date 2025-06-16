// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:student_budget_tracker/models/expense.dart';
import 'package:student_budget_tracker/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  final String userId;
  const ReportsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late FirestoreService _firestoreService;
  DateTime _selectedPeriod = DateTime.now(); // Represents the month/year for the report

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService(userId: widget.userId);
    // Normalize to the first day of the current month for initial display
    _selectedPeriod = DateTime(_selectedPeriod.year, _selectedPeriod.month, 1);
  }

  // Helper to format currency (reused from HomeScreen)
  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₱',
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2,
    );
    return formatter.format(amount);
  }

  // Helper to get category summary for a SPECIFIC period (reused and adapted)
  Map<String, double> _getCategorySummaryForPeriod(List<Expense> expenses, DateTime targetDate, String period) {
    final Map<String, double> summary = {};

    for (var expense in expenses) {
      bool include = false;

      switch (period) {
        case 'monthly':
          if (expense.date.year == targetDate.year && expense.date.month == targetDate.month) {
            include = true;
          }
          break;
        case 'annually':
          if (expense.date.year == targetDate.year) {
            include = true;
          }
          break;
      }

      if (include) {
        summary.update(expense.category, (value) => value + expense.amount,
            ifAbsent: () => expense.amount);
      }
    }
    return summary;
  }

  // Helper to get an icon based on category (copied from HomeScreen)
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.fastfood;
      case 'Transport':
        return Icons.directions_bus;
      case 'Entertainment':
        return Icons.movie;
      case 'Study':
        return Icons.book;
      case 'Rent':
        return Icons.home;
      case 'Utilities':
        return Icons.lightbulb;
      default:
        return Icons.money;
    }
  }

  // Helper widget to build consistent summary cards (reused from HomeScreen and FIXED)
  Widget _buildSummaryCard(String title, double total, Map<String, double> summary, Color titleColor) {
    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(total),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.lightGreenAccent),
            ),
            const SizedBox(height: 10),
            ...sortedEntries.take(3).map((entry) => Text(
              '${entry.key}: ${_formatCurrency(entry.value)}',
              style: Theme.of(context).textTheme.bodyMedium,
            )),
            if (sortedEntries.length > 3)
              Text(
                'Other categories...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  // Function to navigate to the previous month
  void _goToPreviousMonth() {
    setState(() {
      _selectedPeriod = DateTime(_selectedPeriod.year, _selectedPeriod.month - 1, 1);
    });
  }

  // Function to navigate to the next month
  void _goToNextMonth() {
    setState(() {
      _selectedPeriod = DateTime(_selectedPeriod.year, _selectedPeriod.month + 1, 1);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Reports'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Month/Year Selector and Navigation
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Report Period', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.deepPurpleAccent),
                          onPressed: _goToPreviousMonth,
                          tooltip: 'Previous Month',
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _selectedPeriod,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                initialDatePickerMode: DatePickerMode.year,
                                builder: (context, child) {
                                  final currentTheme = Theme.of(context);
                                  return Theme(
                                    data: currentTheme.copyWith(
                                      colorScheme: currentTheme.colorScheme.copyWith(
                                        primary: Colors.deepPurpleAccent,
                                        onPrimary: Colors.white,
                                        onSurface: currentTheme.brightness == Brightness.dark ? Colors.white : Colors.black87,
                                        surface: currentTheme.brightness == Brightness.dark ? Colors.grey[800]! : Colors.white,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.deepPurpleAccent,
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (pickedDate != null && pickedDate != _selectedPeriod) {
                                setState(() {
                                  _selectedPeriod = DateTime(pickedDate.year, pickedDate.month, 1);
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: Text(
                                DateFormat('MMMM yyyy').format(_selectedPeriod), // <--- FIX: Corrected date format
                                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurpleAccent,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.deepPurpleAccent),
                          onPressed: () {
                            if (_selectedPeriod.year < DateTime.now().year ||
                                (_selectedPeriod.year == DateTime.now().year && _selectedPeriod.month < DateTime.now().month)) {
                              _goToNextMonth();
                            }
                          },
                          tooltip: 'Next Month',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Expense>>(
              stream: _firestoreService.getExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No expenses recorded for any period.'));
                }

                final List<Expense> allExpenses = snapshot.data!;

                final monthlyReportSummary = _getCategorySummaryForPeriod(allExpenses, _selectedPeriod, 'monthly');
                final annualReportSummary = _getCategorySummaryForPeriod(allExpenses, _selectedPeriod, 'annually');

                final double totalMonthlyReport = monthlyReportSummary.values.fold(0, (sum, item) => sum + item);
                final double totalAnnualReport = annualReportSummary.values.fold(0, (sum, item) => sum + item);

                final List<Expense> expensesForSelectedMonth = allExpenses.where((expense) {
                  return expense.date.year == _selectedPeriod.year &&
                      expense.date.month == _selectedPeriod.month;
                }).toList()..sort((a,b) => b.timestamp.compareTo(a.timestamp));

                if (expensesForSelectedMonth.isEmpty && totalMonthlyReport == 0 && totalAnnualReport == 0) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('No expenses recorded for ${DateFormat('MMMM yyyy').format(_selectedPeriod)}.'), // <--- FIX: Corrected date format
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monthly/Annual Summary Cards for the selected period
                      Row(
                        children: [
                          Expanded(child: _buildSummaryCard('Selected Month\'s Expenses', totalMonthlyReport, monthlyReportSummary, Colors.blueAccent)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildSummaryCard('Selected Year\'s Expenses', totalAnnualReport, annualReportSummary, Colors.greenAccent)),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Bar Chart for the selected month
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expense Breakdown (${DateFormat('MMMM yyyy').format(_selectedPeriod)})', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent)), // <--- FIX: Corrected date format
                              const SizedBox(height: 15),
                              if (monthlyReportSummary.isNotEmpty)
                                SizedBox(
                                  height: 200,
                                  child: BarChart(
                                    BarChartData(
                                      barGroups: monthlyReportSummary.entries.toList().asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final mapEntry = entry.value;
                                        return BarChartGroupData(
                                          x: index,
                                          barRods: [
                                            BarChartRodData(
                                              toY: mapEntry.value,
                                              color: Colors.primaries[index % Colors.primaries.length],
                                              width: 16,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                      titlesData: FlTitlesData(
                                        show: true,
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              final categoryName = monthlyReportSummary.keys.elementAt(value.toInt());
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(categoryName, style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 9)),
                                              );
                                            },
                                            reservedSize: 30,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              return Text(_formatCurrency(value), style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 9));
                                            },
                                            reservedSize: 45,
                                          ),
                                        ),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10,
                                        getDrawingHorizontalLine: (value) => FlLine(
                                          color: Colors.grey.withOpacity(0.3),
                                          strokeWidth: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('Not enough data for this month\'s bar chart.'),
                                    )),
                              const SizedBox(height: 25),
                              // Pie Chart for the selected month
                              if (monthlyReportSummary.isNotEmpty)
                                SizedBox(
                                  height: 250,
                                  child: PieChart(
                                    PieChartData(
                                      sections: monthlyReportSummary.entries.toList().asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final mapEntry = entry.value;
                                        final color = Colors.primaries[index % Colors.primaries.length];
                                        final percentage = (mapEntry.value / totalMonthlyReport * 100);

                                        final String titleText = percentage > 5.0
                                            ? '${mapEntry.key}\n${percentage.toStringAsFixed(1)}%'
                                            : '${percentage.toStringAsFixed(1)}%';

                                        return PieChartSectionData(
                                          color: color,
                                          value: mapEntry.value,
                                          title: titleText,
                                          radius: 80, // Increased radius for more space
                                          titleStyle: const TextStyle(
                                            fontSize: 10, // Adjusted font size
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          titlePositionPercentageOffset: 0.6, // Adjusted position further out
                                        );
                                      }).toList(),
                                      sectionsSpace: 4, // Increased space between sections
                                      centerSpaceRadius: 50, // Increased center hole size
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                                )
                              else
                                const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('Not enough data for this month\'s pie chart.'),
                                    )),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Expense List for the selected month
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expenses for ${DateFormat('MMMM yyyy').format(_selectedPeriod)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)), // <--- FIX: Corrected date format
                              const SizedBox(height: 15),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: expensesForSelectedMonth.length,
                                itemBuilder: (context, index) {
                                  final expense = expensesForSelectedMonth[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
                                        child: Icon(_getCategoryIcon(expense.category), color: Colors.deepPurpleAccent),
                                      ),
                                      title: Text(
                                        '${expense.category}: ${_formatCurrency(expense.amount)}',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expense.description ?? 'No description',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                          Text(
                                            DateFormat('MMM d, EEEE').format(expense.date),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
