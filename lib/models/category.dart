// lib/models/category.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id; // This will be the Firestore document ID (which is the category name)
  final String name;

  Category({
    required this.id,
    required this.name,
  });

  // Factory constructor to create a Category from a Firestore DocumentSnapshot
  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id, // The document ID is the category name in your setup
      name: data['name'] ?? '', // Assuming 'name' field exists in the document
    );
  }

  // Method to convert a Category object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      // The 'id' (which is the category name) is used as the document ID,
      // so it's often not duplicated as a field inside the document.
      // However, including it can sometimes simplify data retrieval if needed.
    };
  }
}
