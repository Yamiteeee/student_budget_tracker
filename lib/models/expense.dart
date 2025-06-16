import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add this import for DateFormat

class Expense {
  final String id;
  final double amount;
  final String category;
  final String? description;
  final DateTime date; // Stored as a DateTime object
  final DateTime timestamp; // Firestore server timestamp

  Expense({
    required this.id,
    required this.amount,
    required this.category,
    this.description,
    required this.date,
    required this.timestamp,
  });

  // Factory constructor to create an Expense from a Firestore DocumentSnapshot
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      category: data['category'] as String,
      description: data['description'] as String?,
      // Convert Firestore Timestamp to Dart DateTime
      // 'date' field will be a string in YYYY-MM-DD format
      date: (data['date'] as String).isNotEmpty
          ? DateTime.parse(data['date'])
          : (data['timestamp'] as Timestamp).toDate(), // Fallback to timestamp if date string is empty
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // Convert an Expense object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'date': DateFormat('yyyy-MM-dd').format(date), // Store date as YYYY-MM-DD string
      'timestamp': FieldValue.serverTimestamp(), // Use server timestamp for ordering
    };
  }
}