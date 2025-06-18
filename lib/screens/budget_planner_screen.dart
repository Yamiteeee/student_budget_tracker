// lib/screens/budget_planner_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_budget_tracker/models/budget.dart';
import 'package:student_budget_tracker/models/expense.dart';
import 'package:student_budget_tracker/services/firestore_service.dart';
import 'package:student_budget_tracker/models/category.dart'; // Import Category model

class BudgetPlannerScreen extends StatefulWidget {
  final String userId;

  const BudgetPlannerScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<BudgetPlannerScreen> createState() => _BudgetPlannerScreenState();
}

class _BudgetPlannerScreenState extends State<BudgetPlannerScreen> {
  late FirestoreService _firestoreService;
  final TextEditingController _budgetAmountController = TextEditingController();
  String? _selectedCategory; // Make nullable initially
  DateTime _selectedMonth = DateTime.now(); // Represents the month/year for planning

  // Define a threshold for 'nearing exceeding' (e.g., 80% spent)
  static const double _nearExceedingThreshold = 0.80;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService(userId: widget.userId);
    _budgetAmountController.addListener(_onBudgetAmountControllerChanged);

    // Initial load of budget amount for the default/selected category
    // This will be called after categories are loaded for the first time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingBudgetAmount();
    });
  }

  void _onBudgetAmountControllerChanged() {
    // This listener can be used for real-time validation or other UI updates
    // print('Budget Amount Controller Text: ${_budgetAmountController.text}');
  }

  @override
  void dispose() {
    _budgetAmountController.removeListener(_onBudgetAmountControllerChanged);
    _budgetAmountController.dispose();
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

  Future<void> _setBudget() async {
    final double? amount = double.tryParse(_budgetAmountController.text);
    if (amount == null || amount <= 0) {
      _showMessage('Please enter a valid positive budget amount.', isError: true);
      return;
    }
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showMessage('Please select a category.', isError: true);
      return;
    }

    try {
      final budget = Budget(
        category: _selectedCategory!,
        budgetedAmount: amount,
        month: _selectedMonth.month,
        year: _selectedMonth.year,
      );
      await _firestoreService.setBudget(budget);
      _budgetAmountController.clear();
      _showMessage('Budget for $_selectedCategory set successfully for ${DateFormat.yMMM().format(_selectedMonth)}!');
      _loadExistingBudgetAmount(); // Load after successful save/update
    } catch (e) {
      print('Error setting budget: $e');
      _showMessage('Failed to set budget. Please try again.', isError: true);
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    // Custom month picker dialog
    // A simplified month picker is not directly available in Flutter's default DatePicker
    // This uses a workaround to select a date and then extracts month/year.
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year, // Start with year selection
      builder: (BuildContext context, Widget? child) {
        // You can customize the theme for the date picker if needed
        return Theme(
          data: ThemeData.light().copyWith( // Use light theme for date picker or inherit
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurpleAccent, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black87, // Body text color
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

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked; // Update to the selected month/year
      });
      _loadExistingBudgetAmount(); // Load budget for the newly selected month
    }
  }

  Future<void> _loadExistingBudgetAmount() async {
    // Only attempt to load if a category is selected
    if (_selectedCategory != null) {
      print('Attempting to load budget for category: $_selectedCategory, month: ${_selectedMonth.month}, year: ${_selectedMonth.year}');
      final budget = await _firestoreService.getBudgetForCategory(
        _selectedCategory!,
        _selectedMonth.month,
        _selectedMonth.year,
      );
      if (budget != null) {
        _budgetAmountController.text = budget.budgetedAmount.toString();
        print('Loaded budget: ${budget.budgetedAmount}');
      } else {
        _budgetAmountController.clear();
        print('No existing budget found. Clearing amount field.');
      }
    } else {
      _budgetAmountController.clear();
      print('No category selected yet for loading budget.');
    }
  }

  Future<void> _confirmDeleteBudget(Budget budget) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete the budget for "${budget.category}" for ${DateFormat.yMMM().format(DateTime(budget.year, budget.month))}? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteBudget(budget.category, budget.month, budget.year);
        _showMessage('Budget for ${budget.category} deleted successfully!');
      } catch (e) {
        print('Error deleting budget: $e');
        _showMessage('Failed to delete budget. Please try again.', isError: true);
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

  double _calculateSpentAmount(List<Expense> expenses, String category, int month, int year) {
    return expenses
        .where((exp) =>
    exp.category == category &&
        exp.date.month == month &&
        exp.date.year == year)
        .fold(0.0, (sum, exp) => sum + exp.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Planner'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Month Selector
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Planning for: ${DateFormat.yMMM().format(_selectedMonth)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => _selectMonth(context),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Change Month'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Set Budget Form
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Set Monthly Budget', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                    const SizedBox(height: 15),
                    // Category Dropdown (now uses StreamBuilder for dynamic categories)
                    StreamBuilder<List<Category>>(
                      stream: _firestoreService.getCategories(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text('Error loading categories: ${snapshot.error}');
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('No categories available. Please add one in Expense tab.');
                        }

                        List<String> categoryNames = snapshot.data!.map((c) => c.name).toList();

                        // If _selectedCategory is not yet set or not in the current list,
                        // default to the first category if available.
                        if (_selectedCategory == null || !categoryNames.contains(_selectedCategory)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && categoryNames.isNotEmpty) {
                              setState(() {
                                _selectedCategory = categoryNames.first;
                              });
                              _loadExistingBudgetAmount(); // Load budget for the new default category
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
                            _loadExistingBudgetAmount(); // Load existing budget for this new category
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _budgetAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budgeted Amount (₱)',
                        hintText: 'e.g., 500.00',
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
                          return 'Please enter a budget amount';
                        }
                        if (double.tryParse(value) == null || double.parse(value) <= 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _setBudget,
                        icon: const Icon(Icons.save, size: 28),
                        label: const Text('Save Budget', style: TextStyle(fontSize: 18)),
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
            const SizedBox(height: 25),

            // Budget Overview (remains largely the same, but now uses dynamic categories)
            StreamBuilder<List<Budget>>(
              stream: _firestoreService.getBudgetsForMonth(_selectedMonth.month, _selectedMonth.year),
              builder: (context, budgetSnapshot) {
                if (budgetSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (budgetSnapshot.hasError) {
                  return Center(child: Text('Error loading budgets: ${budgetSnapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                if (!budgetSnapshot.hasData || budgetSnapshot.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No budgets set for this month.'),
                    ),
                  );
                }

                final List<Budget> budgets = budgetSnapshot.data!;

                return StreamBuilder<List<Expense>>(
                  stream: _firestoreService.getExpenses(),
                  builder: (context, expenseSnapshot) {
                    if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (expenseSnapshot.hasError) {
                      return Center(child: Text('Error loading expenses: ${expenseSnapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                    }

                    final List<Expense> expenses = expenseSnapshot.data ?? [];

                    return Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Budgets for ${DateFormat.yMMM().format(_selectedMonth)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                            ),
                            const SizedBox(height: 15),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: budgets.length,
                              itemBuilder: (context, index) {
                                final budget = budgets[index];
                                final spent = _calculateSpentAmount(expenses, budget.category, budget.month, budget.year);
                                final remaining = budget.budgetedAmount - spent;
                                final bool isOverBudget = remaining < 0;

                                final double percentSpent = budget.budgetedAmount > 0 ? (spent / budget.budgetedAmount) : 0.0;
                                final bool isNearExceeding = !isOverBudget && percentSpent >= _nearExceedingThreshold;

                                Color cardBackgroundColor = Theme.of(context).cardColor;
                                if (isOverBudget) {
                                  cardBackgroundColor = Colors.red.shade50;
                                } else if (isNearExceeding) {
                                  cardBackgroundColor = Colors.orange.shade50;
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  color: cardBackgroundColor,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
                                      child: Icon(_getCategoryIcon(budget.category), color: Colors.deepPurpleAccent),
                                    ),
                                    title: Text(
                                      '${budget.category} Budget: ${_formatCurrency(budget.budgetedAmount)}',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Spent: ${_formatCurrency(spent)}'),
                                        Text(
                                          'Remaining: ${_formatCurrency(remaining)}',
                                          style: TextStyle(
                                            color: isOverBudget ? Colors.redAccent : Colors.lightGreenAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isOverBudget)
                                          const Text(
                                            'Budget Exceeded!',
                                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        if (isNearExceeding)
                                          const Text(
                                            'Approaching Budget Limit!',
                                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        LinearProgressIndicator(
                                          value: spent > budget.budgetedAmount ? 1.0 : (budget.budgetedAmount > 0 ? spent / budget.budgetedAmount : 0.0),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isOverBudget ? Colors.red : (isNearExceeding ? Colors.orange : Colors.green),
                                          ),
                                          backgroundColor: Colors.grey[300],
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                          onPressed: () {
                                            // Pre-fill the form with the budget details for editing
                                            setState(() {
                                              _selectedCategory = budget.category;
                                              _selectedMonth = DateTime(budget.year, budget.month, 1);
                                              _budgetAmountController.text = budget.budgetedAmount.toString();
                                            });
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () => _confirmDeleteBudget(budget),
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
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get a relevant icon for the category (optional)
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
        return Icons.money; // Default icon for unknown categories
    }
  }
}