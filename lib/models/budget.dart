// lib/models/budget.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Budget {
  String? id; // Document ID from Firestore
  String category;
  double budgetedAmount;
  int month; // Month (1-12)
  int year;  // Year

  Budget({
    this.id,
    required this.category,
    required this.budgetedAmount,
    required this.month,
    required this.year,
  });

  // Factory constructor to create a Budget from a Firestore document
  factory Budget.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Budget(
      id: doc.id,
      category: data['category'] ?? '',
      budgetedAmount: (data['budgetedAmount'] ?? 0.0).toDouble(),
      month: data['month'] ?? 0,
      year: data['year'] ?? 0,
    );
  }

  // Convert Budget object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'budgetedAmount': budgetedAmount,
      'month': month,
      'year': year,
    };
  }
}