// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:student_budget_tracker/models/expense.dart';
import 'package:student_budget_tracker/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final VoidCallback toggleThemeMode; // Add this callback for theme toggling

  const HomeScreen({
    Key? key,
    required this.userId,
    required this.toggleThemeMode, // Require it in the constructor
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isAddingExpense = false;

  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService(userId: widget.userId);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _addExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isAddingExpense = true;
      });

      final double? amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        _showMessage('Please enter a valid amount.', isError: true);
        setState(() { _isAddingExpense = false; });
        return;
      }

      try {
        final newExpense = Expense(
          id: '',
          amount: amount,
          category: _selectedCategory,
          description: _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          date: _selectedDate,
          timestamp: DateTime.now(),
        );
        await _firestoreService.addExpense(newExpense);
        _amountController.clear();
        _descriptionController.clear();
        _showMessage('Expense added successfully!');
      } catch (e) {
        print('Error adding expense: $e');
        _showMessage('Failed to add expense. Please try again.', isError: true);
      } finally {
        setState(() {
          _isAddingExpense = false;
        });
      }
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this expense?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await _firestoreService.deleteExpense(expenseId);
        _showMessage('Expense deleted successfully!');
      } catch (e) {
        print('Error deleting expense: $e');
        _showMessage('Failed to delete expense. Please try again.', isError: true);
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '₱');
    return formatter.format(amount);
  }

  Map<String, double> _getCategorySummary(List<Expense> expenses, String period) {
    final Map<String, double> summary = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var expense in expenses) {
      final expenseDateNormalized = DateTime(expense.date.year, expense.date.month, expense.date.day);

      bool include = false;
      if (period == 'daily') {
        if (expenseDateNormalized.isAtSameMomentAs(today)) {
          include = true;
        }
      } else if (period == 'weekly') {
        final int currentWeekday = today.weekday;
        final DateTime startOfWeek = today.subtract(Duration(days: currentWeekday % 7));

        if (expenseDateNormalized.isAfter(startOfWeek) || expenseDateNormalized.isAtSameMomentAs(startOfWeek)) {
          final Duration diff = expenseDateNormalized.difference(startOfWeek);
          if (diff.inDays >= 0 && diff.inDays <= 6) {
            include = true;
          }
        }
      }

      if (include) {
        summary.update(expense.category, (value) => value + expense.amount,
            ifAbsent: () => expense.amount);
      }
    }
    return summary;
  }

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

  @override
  Widget build(BuildContext context) {
    // Determine current brightness to change icon dynamically
    final Brightness currentBrightness = Theme.of(context).brightness;
    final IconData themeIcon = currentBrightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Budget Tracker'),
        centerTitle: true,
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(themeIcon),
            onPressed: widget.toggleThemeMode, // Call the passed callback
            tooltip: 'Toggle Theme',
          ),
          // User ID display removed from here
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User ID Display removed from here
            // const SizedBox(height: 20), // Remove or reduce this space if the User ID section was here

            // Add Expense Form (ALWAYS VISIBLE)
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add New Expense', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₱)',
                          hintText: 'e.g., 15.50',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(left: 12.0, right: 8.0, top: 4.0),
                            child: Text(
                              '₱',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category, color: Colors.orangeAccent),
                        ),
                        items: <String>[
                          'Food', 'Transport', 'Entertainment', 'Study', 'Rent', 'Utilities', 'Other'
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue!;
                          });
                        },
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'e.g., Lunch at cafeteria',
                          prefixIcon: Icon(Icons.description, color: Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ListTile(
                        title: Text(
                          'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                          // Text color will adapt based on the overall theme TextTheme
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.tealAccent),
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              final currentTheme = Theme.of(context);
                              return Theme(
                                data: currentTheme.copyWith(
                                  colorScheme: currentTheme.colorScheme.copyWith(
                                    primary: Colors.deepPurpleAccent, // Header background
                                    onPrimary: Colors.white, // Header text
                                    onSurface: currentTheme.brightness == Brightness.dark ? Colors.white : Colors.black87, // Calendar text
                                    surface: currentTheme.brightness == Brightness.dark ? Colors.grey[800]! : Colors.white, // Calendar background
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.deepPurpleAccent, // Button text color
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedDate != null && pickedDate != _selectedDate) {
                            setState(() {
                              _selectedDate = pickedDate;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: _isAddingExpense
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                          onPressed: _addExpense,
                          icon: const Icon(Icons.add_circle, size: 28),
                          label: const Text('Add Expense', style: TextStyle(fontSize: 18)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 5,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // StreamBuilder for dynamic content (summaries, charts, expense list)
            StreamBuilder<List<Expense>>(
              stream: _firestoreService.getExpenses(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No expenses recorded yet.'));
                }

                final List<Expense> expenses = snapshot.data!;
                final dailySummary = _getCategorySummary(expenses, 'daily');
                final weeklySummary = _getCategorySummary(expenses, 'weekly');
                final double totalDaily = dailySummary.values.fold(0, (sum, item) => sum + item);
                final double totalWeekly = weeklySummary.values.fold(0, (sum, item) => sum + item);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Section
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Today\'s Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatCurrency(totalDaily),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.lightGreenAccent),
                                  ),
                                  const SizedBox(height: 10),
                                  ...dailySummary.entries.map((entry) => Text(
                                    '${entry.key}: ${_formatCurrency(entry.value)}',
                                    style: Theme.of(context).textTheme.bodyMedium, // Use theme's text color
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('This Week\'s Expenses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatCurrency(totalWeekly),
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.lightGreenAccent),
                                  ),
                                  const SizedBox(height: 10),
                                  ...weeklySummary.entries.map((entry) => Text(
                                    '${entry.key}: ${_formatCurrency(entry.value)}',
                                    style: Theme.of(context).textTheme.bodyMedium, // Use theme's text color
                                  )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Charts Section
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expense Breakdown (Weekly)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                            const SizedBox(height: 15),
                            // Bar Chart
                            if (weeklySummary.isNotEmpty)
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    barGroups: weeklySummary.entries.toList().asMap().entries.map((entry) {
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
                                            final categoryName = weeklySummary.keys.elementAt(value.toInt());
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(categoryName, style: Theme.of(context).textTheme.bodySmall), // Use theme's text color
                                            );
                                          },
                                          reservedSize: 30,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            return Text(_formatCurrency(value), style: Theme.of(context).textTheme.bodySmall); // Use theme's text color
                                          },
                                          reservedSize: 40,
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
                                    child: Text('Not enough data for weekly bar chart.'),
                                  )),
                            const SizedBox(height: 25),
                            // Pie Chart
                            if (weeklySummary.isNotEmpty)
                              SizedBox(
                                height: 250,
                                child: PieChart(
                                  PieChartData(
                                    sections: weeklySummary.entries.toList().asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final mapEntry = entry.value;
                                      final color = Colors.primaries[index % Colors.primaries.length];
                                      final percentage = (mapEntry.value / totalWeekly * 100);
                                      return PieChartSectionData(
                                        color: color,
                                        value: mapEntry.value,
                                        title: '${mapEntry.key}\n${percentage.toStringAsFixed(1)}%',
                                        radius: 70,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        titlePositionPercentageOffset: 0.55,
                                      );
                                    }).toList(),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              )
                            else
                              const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text('Not enough data for weekly pie chart.'),
                                  )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Expense List
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('All Expenses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            const SizedBox(height: 15),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: expenses.length,
                              itemBuilder: (context, index) {
                                final expense = expenses[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  // Card color will now be controlled by the theme's cardColor
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
                                      child: Icon(_getCategoryIcon(expense.category), color: Colors.deepPurpleAccent),
                                    ),
                                    title: Text(
                                      '${expense.category}: ${_formatCurrency(expense.amount)}',
                                      style: Theme.of(context).textTheme.titleMedium, // Use theme's text color
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.description ?? 'No description',
                                          style: Theme.of(context).textTheme.bodyMedium, // Use theme's text color
                                        ),
                                        Text(
                                          DateFormat('MMM d, EEEE').format(expense.date), // Changed YYYY to EEEE for day of week
                                          style: Theme.of(context).textTheme.bodySmall, // Use theme's text color
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      onPressed: () => _deleteExpense(expense.id),
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}