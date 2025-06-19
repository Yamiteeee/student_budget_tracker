// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth to get current user ID
import 'package:student_budget_tracker/models/expense.dart';
import 'package:student_budget_tracker/models/budget.dart';
import 'package:student_budget_tracker/models/category.dart'; // Import the Category model

class FirestoreService {
  final String userId; // Now truly relies on the userId passed in
  late final CollectionReference _expensesCollection;
  late final CollectionReference _budgetsCollection;
  late final CollectionReference _categoriesCollection; // Collection reference for global categories

  FirestoreService({required this.userId}) {
    const String appId = 'student_budget_tracker_app'; // Your defined app ID

    // User-specific collections
    final userDocRef = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('users')
        .doc(userId);

    _expensesCollection = userDocRef.collection('expenses');
    _budgetsCollection = userDocRef.collection('budgets');

    // Global categories collection (as per your current setup)
    _categoriesCollection = FirebaseFirestore.instance
        .collection('artifacts')
        .doc(appId)
        .collection('categories');
  }

  // --- Expense Operations (Existing) ---
  Future<void> addExpense(Expense expense) {
    return _expensesCollection.add(expense.toFirestore());
  }

  Stream<List<Expense>> getExpenses() {
    return _expensesCollection.snapshots().map((snapshot) {
      final expenses =
      snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
      expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return expenses;
    });
  }

  Future<void> deleteExpense(String expenseId) {
    return _expensesCollection.doc(expenseId).delete();
  }

  // --- Budget Operations (Existing) ---
  Future<void> setBudget(Budget budget) async {
    final String budgetDocId = '${budget.category}_${budget.month}_${budget.year}';
    await _budgetsCollection.doc(budgetDocId).set(budget.toMap());
  }

  Future<Budget?> getBudgetForCategory(String category, int month, int year) async {
    final String budgetDocId = '${category}_${month}_${year}';
    DocumentSnapshot doc = await _budgetsCollection.doc(budgetDocId).get();
    if (doc.exists) {
      return Budget.fromFirestore(doc);
    }
    return null;
  }

  Stream<List<Budget>> getBudgetsForMonth(int month, int year) {
    return _budgetsCollection
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Budget.fromFirestore(doc))
        .toList());
  }

  Future<void> deleteBudget(String category, int month, int year) async {
    final String budgetDocId = '${category}_${month}_${year}';
    await _budgetsCollection.doc(budgetDocId).delete();
  }

  // --- Category Operations ---

  /// Adds a new category to Firestore.
  /// Uses the category name as the document ID to prevent duplicates.
  Future<void> addCategory(String categoryName) async {
    final String normalizedCategoryName = categoryName.trim();
    if (normalizedCategoryName.isEmpty) {
      throw Exception('Category name cannot be empty.');
    }

    final docRef = _categoriesCollection.doc(normalizedCategoryName);
    final doc = await docRef.get();
    if (doc.exists) {
      throw Exception('Category "$normalizedCategoryName" already exists.');
    }
    return docRef.set(Category(id: normalizedCategoryName, name: normalizedCategoryName).toFirestore());
  }

  /// Gets a stream of all categories from Firestore, sorted alphabetically by name.
  /// Also adds default categories if the collection is initially empty.
  Stream<List<Category>> getCategories() {
    return _categoriesCollection.orderBy('name').snapshots().map((snapshot) {
      final categories = snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();
      // Add default categories if the collection is empty.
      if (categories.isEmpty) {
        _addDefaultCategoriesIfEmpty();
      }
      return categories;
    });
  }

  /// Removes a category from Firestore by its ID (which is its name in your setup).
  ///
  /// IMPORTANT: This method now also attempts to delete associated budget and
  /// expense entries for the *current user* to maintain data consistency.
  Future<void> removeCategory(String categoryId) async {
    try {
      // Start a Firestore batch write for atomicity
      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Delete the category itself from the global collection
      batch.delete(_categoriesCollection.doc(categoryId));

      // 2. Query and delete associated budget entries for the current user
      final budgetsToDelete = await _budgetsCollection
          .where('category', isEqualTo: categoryId)
          .get();
      for (var doc in budgetsToDelete.docs) {
        batch.delete(doc.reference);
      }
      print('Found ${budgetsToDelete.docs.length} budgets to delete for category "$categoryId".');


      // 3. Query and delete associated expense entries for the current user
      final expensesToDelete = await _expensesCollection
          .where('category', isEqualTo: categoryId)
          .get();
      for (var doc in expensesToDelete.docs) {
        batch.delete(doc.reference);
      }
      print('Found ${expensesToDelete.docs.length} expenses to delete for category "$categoryId".');

      // Commit the batch operation
      await batch.commit();

      print('Category "$categoryId" and all associated budgets/expenses removed successfully.');
    } catch (e) {
      print('Error removing category "$categoryId" or associated data: $e');
      rethrow; // Re-throw to allow UI to handle the error
    }
  }


  /// Private helper method to populate default categories if none exist.
  Future<void> _addDefaultCategoriesIfEmpty() async {
    final defaultCategories = ['Food', 'Transport', 'Entertainment', 'Study', 'Rent', 'Utilities', 'Other'];
    for (String categoryName in defaultCategories) {
      try {
        await addCategory(categoryName);
      } catch (e) {
        // Log the error but continue. This handles cases where a default category
        // might already exist (e.g., if multiple instances try to add at once).
        print('Error adding default category "$categoryName": $e');
      }
    }
  }
}
