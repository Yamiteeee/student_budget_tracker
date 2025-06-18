// lib/models/category.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id; // Document ID, typically the category name
  final String name;

  Category({required this.id, required this.name});

  // Factory constructor to create a Category object from a Firestore DocumentSnapshot
  factory Category.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id, // Use doc.id as the category ID for uniqueness
      name: data['name'] as String,
    );
  }

  // Method to convert a Category object into a Map for Firestore storage
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'timestamp': FieldValue.serverTimestamp(), // Optional: To track when it was added
    };
  }
}