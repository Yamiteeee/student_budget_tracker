// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:student_budget_tracker/models/expense.dart';
import 'package:student_budget_tracker/services/firestore_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:student_budget_tracker/screens/reports_screen.dart';
import 'package:student_budget_tracker/screens/budget_planner_screen.dart';
import 'package:student_budget_tracker/models/category.dart'; // NEW: Import Category model

class HomeScreen extends StatefulWidget {
  final String userId;
  final VoidCallback toggleThemeMode;

  const HomeScreen({
    Key? key,
    required this.userId,
    required this.toggleThemeMode,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory; // Change to nullable initially
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
      final double? amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        _showMessage('Please enter a valid positive amount.', isError: true);
        return;
      }
      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _showMessage('Please select a category.', isError: true);
        return;
      }

      setState(() {
        _isAddingExpense = true;
      });

      try {
        final newExpense = Expense(
          id: '', // Firestore will generate this
          amount: amount,
          category: _selectedCategory!,
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
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '₱',
      decimalDigits: amount.truncateToDouble() == amount ? 0 : 2,
    );
    return formatter.format(amount);
  }

  Map<String, double> _getCategorySummary(List<Expense> expenses, String period) {
    final Map<String, double> summary = {};
    final now = DateTime.now();

    for (var expense in expenses) {
      bool include = false;

      switch (period) {
        case 'daily':
          final today = DateTime(now.year, now.month, now.day);
          final expenseDateNormalized =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
          if (expenseDateNormalized.isAtSameMomentAs(today)) {
            include = true;
          }
          break;
        case 'weekly':
          final todayNormalized = DateTime(now.year, now.month, now.day);
          final int currentWeekday = todayNormalized.weekday;
          // Adjust to start week on Monday (1) or Sunday (7). Assuming Monday:
          final DateTime startOfWeek =
          todayNormalized.subtract(Duration(days: currentWeekday == 7 ? 6 : currentWeekday - 1)); // Mon=1, Sun=7. If Sun, go back 6 days. Else, currentWeekday-1 days.

          final expenseDateNormalized =
          DateTime(expense.date.year, expense.date.month, expense.date.day);
          if ((expenseDateNormalized.isAfter(startOfWeek) ||
              expenseDateNormalized.isAtSameMomentAs(startOfWeek)) &&
              expenseDateNormalized.isBefore(startOfWeek.add(const Duration(days: 7)))) {
            include = true;
          }
          break;
        case 'monthly':
          if (expense.date.year == now.year && expense.date.month == now.month) {
            include = true;
          }
          break;
        case 'annually':
          if (expense.date.year == now.year) {
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

  // NEW: Dialog to add a new category
  Future<void> _showAddCategoryDialog() async {
    final TextEditingController newCategoryController = TextEditingController();
    final String? newCategory = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add New Category'),
          content: TextField(
            controller: newCategoryController,
            decoration: const InputDecoration(hintText: 'Category Name'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String categoryName = newCategoryController.text.trim();
                if (categoryName.isNotEmpty) {
                  Navigator.of(dialogContext).pop(categoryName);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Category name cannot be empty.'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      try {
        await _firestoreService.addCategory(newCategory);
        _showMessage('Category "$newCategory" added successfully!');
        setState(() {
          _selectedCategory = newCategory; // Automatically select the newly added category
        });
      } catch (e) {
        String errorMessage = e.toString().split(':').last.trim();
        _showMessage('Failed to add category: $errorMessage', isError: true);
      }
    }
    newCategoryController.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final Brightness currentBrightness = Theme.of(context).brightness;
    final IconData themeIcon =
    currentBrightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(themeIcon),
            onPressed: widget.toggleThemeMode,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportsScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'View Past Reports',
          ),
          IconButton(
            icon: const Icon(Icons.wallet),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetPlannerScreen(userId: widget.userId),
                ),
              );
            },
            tooltip: 'Plan Budgets',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Expense Form
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
                      const Text('Add New Expense',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurpleAccent)),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (₱)',
                          hintText: 'e.g., 15.50',
                          prefixIcon: SizedBox(
                            width: 36,
                            child: Center(
                              child: Text(
                                '₱',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an amount';
                          }
                          if (double.tryParse(value) == null ||
                              double.parse(value) <= 0) {
                            return 'Please enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // NEW: Category Dropdown with Add Button
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<List<Category>>(
                              stream: _firestoreService.getCategories(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }
                                if (snapshot.hasError) {
                                  return Text('Error loading categories: ${snapshot.error}');
                                }
                                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  // Inform user to add a category if none exist
                                  return const Text('No categories available. Please add one.');
                                }

                                List<String> categoryNames = snapshot.data!.map((c) => c.name).toList();

                                // Ensure _selectedCategory is a valid value from the fetched list
                                // If _selectedCategory is null or not in the current list, set to the first category
                                if (_selectedCategory == null || !categoryNames.contains(_selectedCategory)) {
                                  // Use addPostFrameCallback to avoid calling setState during build
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted && categoryNames.isNotEmpty) {
                                      setState(() {
                                        _selectedCategory = categoryNames.first;
                                      });
                                    }
                                  });
                                }

                                return DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    prefixIcon: Icon(Icons.category, color: Colors.orangeAccent),
                                  ),
                                  items: categoryNames.map<DropdownMenuItem<String>>((String value) {
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
                                  // Validator for dropdown
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select a category';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: _showAddCategoryDialog,
                              tooltip: 'Add New Category',
                            ),
                          ),
                        ],
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
                        ),
                        trailing:
                        const Icon(Icons.calendar_today, color: Colors.tealAccent),
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
                                    primary: Colors.deepPurpleAccent,
                                    onPrimary: Colors.white,
                                    onSurface: currentTheme.brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                    surface: currentTheme.brightness == Brightness.dark
                                        ? Colors.grey[800]!
                                        : Colors.white,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 12),
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
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No expenses recorded yet.'));
                }
                final List<Expense> expenses = snapshot.data!;
                final dailySummary = _getCategorySummary(expenses, 'daily');
                final weeklySummary = _getCategorySummary(expenses, 'weekly');
                final monthlySummary = _getCategorySummary(expenses, 'monthly');
                final annuallySummary = _getCategorySummary(expenses, 'annually');
                final double totalDaily =
                dailySummary.values.fold(0, (sum, item) => sum + item);
                final double totalWeekly =
                weeklySummary.values.fold(0, (sum, item) => sum + item);
                final double totalMonthly =
                monthlySummary.values.fold(0, (sum, item) => sum + item);
                final double totalAnnually =
                annuallySummary.values.fold(0, (sum, item) => sum + item);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Sections (Daily, Weekly, Monthly, Annually)
                    Row(
                      children: [
                        Expanded(
                            child: _buildSummaryCard('Today\'s Expenses', totalDaily,
                                dailySummary, Colors.orangeAccent)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildSummaryCard('This Week\'s Expenses', totalWeekly,
                                weeklySummary, Colors.orangeAccent)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                            child: _buildSummaryCard('This Month\'s Expenses', totalMonthly,
                                monthlySummary, Colors.blueAccent)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildSummaryCard('This Year\'s Expenses', totalAnnually,
                                annuallySummary, Colors.greenAccent)),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Charts Section (Weekly)
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expense Breakdown (Weekly)',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.tealAccent)),
                            const SizedBox(height: 15),
                            // Bar Chart
                            if (weeklySummary.isNotEmpty)
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    barGroups: weeklySummary.entries
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final mapEntry = entry.value;
                                      return BarChartGroupData(
                                        x: index,
                                        barRods: [
                                          BarChartRodData(
                                            toY: mapEntry.value,
                                            color: Colors.primaries[
                                            index % Colors.primaries.length],
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
                                            final categoryName =
                                            weeklySummary.keys.elementAt(value.toInt());
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: Text(categoryName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .copyWith(fontSize: 9)),
                                            );
                                          },
                                          reservedSize: 30,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            return Text(_formatCurrency(value),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall!
                                                    .copyWith(fontSize: 9));
                                          },
                                          reservedSize: 45,
                                        ),
                                      ),
                                      topTitles:
                                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles:
                                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 10,
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
                                    sections: weeklySummary.entries
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final mapEntry = entry.value;
                                      final color = Colors
                                          .primaries[index % Colors.primaries.length];
                                      final percentage =
                                      (mapEntry.value / totalWeekly * 100);
                                      final String titleText = percentage > 5.0
                                          ? '${mapEntry.key}\n${percentage.toStringAsFixed(1)}%'
                                          : '${percentage.toStringAsFixed(1)}%';

                                      return PieChartSectionData(
                                        color: color,
                                        value: mapEntry.value,
                                        title: titleText,
                                        radius: 80,
                                        titleStyle: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        titlePositionPercentageOffset:
                                        0.6,
                                      );
                                    }).toList(),
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 50,
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
                            const Text('All Expenses',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.greenAccent)),
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
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                      Colors.deepPurpleAccent.withOpacity(0.2),
                                      child: Icon(_getCategoryIcon(expense.category),
                                          color: Colors.deepPurpleAccent),
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

  Widget _buildSummaryCard(String title, double total, Map<String, double> summary,
      Color titleColor) {
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
            Text(title,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: titleColor)),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(total),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightGreenAccent),
            ),
            const SizedBox(height: 10),
            // Display top 3 categories by amount
            ...sortedEntries.take(3).map((entry) => Text(
              '${entry.key}: ${_formatCurrency(entry.value)}',
              style: Theme.of(context).textTheme.bodyMedium,
            )),
            // If there are more than 3 categories, show "..."
            if (sortedEntries.length > 3)
              Text(
                '...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}