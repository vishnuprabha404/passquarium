import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:super_locker/models/password_entry.dart';
import 'package:super_locker/services/auth_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'password_entries';

  final AuthService _authService = AuthService();

  // Get user's device ID for data isolation
  Future<String> _getDeviceId() async {
    final deviceInfo = await _authService.getDeviceInfo();
    return deviceInfo['device_id'] ?? 'unknown_device';
  }

  // Add an encrypted password entry
  Future<void> addEntry(PasswordEntry entry) async {
    try {
      final deviceId = await _getDeviceId();

      final docRef = _firestore.collection(_collectionName).doc();

      final entryData = {
        'id': docRef.id,
        'device_id': deviceId,
        'title': entry.title,
        'username': entry.username,
        'encrypted_password': entry.encryptedPassword,
        'url': entry.url,
        'notes': entry.notes,
        'category': entry.category,
        'salt': entry.salt,
        'iv': entry.iv,
        'created_at': entry.createdAt.toIso8601String(),
        'updated_at': entry.updatedAt.toIso8601String(),
        'version': 1, // For future data migration
      };

      await docRef.set(entryData);
      // Entry added successfully
    } catch (e) {
      throw Exception('Failed to add password entry: $e');
    }
  }

  // Update an existing password entry
  Future<void> updateEntry(PasswordEntry entry) async {
    try {
      final deviceId = await _getDeviceId();

      final entryData = {
        'device_id': deviceId,
        'title': entry.title,
        'username': entry.username,
        'encrypted_password': entry.encryptedPassword,
        'url': entry.url,
        'notes': entry.notes,
        'category': entry.category,
        'salt': entry.salt,
        'iv': entry.iv,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _firestore
          .collection(_collectionName)
          .doc(entry.id)
          .update(entryData);

      // Entry updated successfully
    } catch (e) {
      throw Exception('Failed to update password entry: $e');
    }
  }

  // Delete a password entry
  Future<void> deleteEntry(String entryId) async {
    try {
      await _firestore.collection(_collectionName).doc(entryId).delete();

      // Entry deleted successfully
    } catch (e) {
      throw Exception('Failed to delete password entry: $e');
    }
  }

  // Get all password entries for the current device
  Future<List<PasswordEntry>> getAllEntries() async {
    try {
      final deviceId = await _getDeviceId();

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('device_id', isEqualTo: deviceId)
          .orderBy('updated_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PasswordEntry.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get password entries: $e');
    }
  }

  // Search password entries by keyword
  Future<List<PasswordEntry>> searchEntries(String keyword) async {
    try {
      final deviceId = await _getDeviceId();
      final lowerKeyword = keyword.toLowerCase();

      // Firestore doesn't support full-text search, so we'll get all entries
      // and filter them locally for better search functionality
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('device_id', isEqualTo: deviceId)
          .get();

      final allEntries = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PasswordEntry.fromMap(data);
      }).toList();

      // Filter entries based on keyword match
      return allEntries.where((entry) {
        return entry.title.toLowerCase().contains(lowerKeyword) ||
            entry.username.toLowerCase().contains(lowerKeyword) ||
            entry.url.toLowerCase().contains(lowerKeyword) ||
            entry.notes.toLowerCase().contains(lowerKeyword) ||
            entry.category.toLowerCase().contains(lowerKeyword);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search password entries: $e');
    }
  }

  // Search entries by specific field
  Future<List<PasswordEntry>> searchByField(String field, String value) async {
    try {
      final deviceId = await _getDeviceId();

      Query query = _firestore
          .collection(_collectionName)
          .where('device_id', isEqualTo: deviceId);

      // Add field-specific filter
      switch (field.toLowerCase()) {
        case 'title':
          query = query
              .where('title', isGreaterThanOrEqualTo: value)
              .where('title', isLessThanOrEqualTo: '$value\uf8ff');
          break;
        case 'username':
          query = query
              .where('username', isGreaterThanOrEqualTo: value)
              .where('username', isLessThanOrEqualTo: '$value\uf8ff');
          break;
        case 'url':
          query = query
              .where('url', isGreaterThanOrEqualTo: value)
              .where('url', isLessThanOrEqualTo: '$value\uf8ff');
          break;
        case 'category':
          query = query.where('category', isEqualTo: value);
          break;
        default:
          throw Exception('Invalid search field: $field');
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PasswordEntry.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search by field: $e');
    }
  }

  // Get entries as a stream for real-time updates
  Stream<List<PasswordEntry>> getEntriesStream() {
    return _firestore
        .collection(_collectionName)
        .where('device_id', isEqualTo: _getDeviceId())
        .orderBy('updated_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final deviceId = await _getDeviceId();
      return snapshot.docs
          .where((doc) => doc.data()['device_id'] == deviceId)
          .map((doc) {
        final data = doc.data();
        return PasswordEntry.fromMap(data);
      }).toList();
    });
  }

  // Get entry by ID
  Future<PasswordEntry?> getEntryById(String entryId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collectionName).doc(entryId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return PasswordEntry.fromMap(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get entry by ID: $e');
    }
  }

  // Get entries by category
  Future<List<PasswordEntry>> getEntriesByCategory(String category) async {
    try {
      final deviceId = await _getDeviceId();

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('device_id', isEqualTo: deviceId)
          .where('category', isEqualTo: category)
          .orderBy('updated_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return PasswordEntry.fromMap(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get entries by category: $e');
    }
  }

  // Get all unique categories
  Future<List<String>> getCategories() async {
    try {
      final deviceId = await _getDeviceId();

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('device_id', isEqualTo: deviceId)
          .get();

      final categories = <String>{};
      for (final doc in querySnapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      throw Exception('Failed to get categories: $e');
    }
  }

  // Batch operations for better performance
  Future<void> addMultipleEntries(List<PasswordEntry> entries) async {
    try {
      final batch = _firestore.batch();
      final deviceId = await _getDeviceId();

      for (final entry in entries) {
        final docRef = _firestore.collection(_collectionName).doc();

        final entryData = {
          'id': docRef.id,
          'device_id': deviceId,
          'title': entry.title,
          'username': entry.username,
          'encrypted_password': entry.encryptedPassword,
          'url': entry.url,
          'notes': entry.notes,
          'category': entry.category,
          'salt': entry.salt,
          'iv': entry.iv,
          'created_at': entry.createdAt.toIso8601String(),
          'updated_at': entry.updatedAt.toIso8601String(),
          'version': 1,
        };

        batch.set(docRef, entryData);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add multiple entries: $e');
    }
  }

  // Delete all entries for current device (for reset/logout)
  Future<void> deleteAllEntries() async {
    try {
      final deviceId = await _getDeviceId();

      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('device_id', isEqualTo: deviceId)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete all entries: $e');
    }
  }

  // Sync entries (for offline support)
  Future<void> syncEntries(List<PasswordEntry> localEntries) async {
    try {
      final cloudEntries = await getAllEntries();

      // Simple sync strategy: cloud entries take precedence
      // In a production app, you'd implement proper conflict resolution

      for (final localEntry in localEntries) {
        final cloudEntry = cloudEntries.firstWhere(
          (e) => e.id == localEntry.id,
          orElse: () => PasswordEntry(
            id: '',
            website: '',
            domain: '',
            username: '',
            encryptedPassword: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            title: '',
            url: '',
            notes: '',
            category: '',
            salt: '',
            iv: '',
          ),
        );

        if (cloudEntry.id.isEmpty) {
          // Entry doesn't exist in cloud, add it
          await addEntry(localEntry);
        } else if (localEntry.updatedAt.isAfter(cloudEntry.updatedAt)) {
          // Local entry is newer, update cloud
          await updateEntry(localEntry);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync entries: $e');
    }
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final entries = await getAllEntries();
      final categories = await getCategories();

      final stats = {
        'total_entries': entries.length,
        'total_categories': categories.length,
        'categories': categories,
        'oldest_entry': entries.isNotEmpty
            ? entries
                .map((e) => e.createdAt)
                .reduce((a, b) => a.isBefore(b) ? a : b)
            : null,
        'newest_entry': entries.isNotEmpty
            ? entries
                .map((e) => e.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : null,
      };

      return stats;
    } catch (e) {
      return {};
    }
  }
}
