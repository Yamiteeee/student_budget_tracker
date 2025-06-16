import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_budget_tracker/models/expense.dart';
// No need for 'intl' import here, it's used in Expense model

class FirestoreService {
  final String userId;
  late final CollectionReference _expensesCollection;

  FirestoreService({required this.userId}) {
    // Define the collection path based on Firebase security rules for private user data
    // /artifacts/{appId}/users/{userId}/{your_collection_name}
    // We'll use a placeholder 'student_budget_tracker_app' for __app_id for local consistency.
    // In a Canvas environment, __app_id would be automatically provided.
    _expensesCollection = FirebaseFirestore.instance
        .collection('artifacts')
        .doc('student_budget_tracker_app') // Static app ID, replace with __app_id in Canvas env
        .collection('users')
        .doc(userId)
        .collection('expenses');
  }

  // Add a new expense
  Future<void> addExpense(Expense expense) {
    return _expensesCollection.add(expense.toFirestore());
  }

  // Get a stream of expenses for real-time updates
  Stream<List<Expense>> getExpenses() {
    // Note: Firestore's orderBy is removed as per instructions and potential index issues.
    // Sorting will be done client-side.
    return _expensesCollection.snapshots().map((snapshot) {
      final expenses = snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
      // Client-side sorting by timestamp (descending)
      expenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return expenses;
    });
  }

  // Delete an expense
  Future<void> deleteExpense(String expenseId) {
    return _expensesCollection.doc(expenseId).delete();
  }
}