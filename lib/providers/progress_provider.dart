import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class ProgressProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  Map<String, double> _progressData = {};
  bool _isLoading = true;
  
  Map<String, double> get progressData => _progressData;
  bool get isLoading => _isLoading;
  
  ProgressProvider() {
    // Load progress data when provider is initialized
    loadProgressData();
  }
  
  // Load progress data from Firebase Realtime Database
  Future<void> loadProgressData() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final user = _auth.currentUser;
      if (user == null) {
        _isLoading = false;
        _progressData = {};
        notifyListeners();
        return;
      }
      
      final snapshot = await _database
          .ref()
          .child('skillbench/users/${user.uid}/progress')
          .get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        // Convert the dynamic map to the required format
        final Map<String, double> progressMap = {};
        data.forEach((key, value) {
          if (value is num) {
            progressMap[key.toString()] = value.toDouble();
          }
        });
        
        _progressData = progressMap;
      } else {
        // If no progress data exists yet, initialize with empty map
        _progressData = {};
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading progress data: $e');
      _isLoading = false;
      _progressData = {};
      notifyListeners();
    }
  }
  
  // Update progress for a specific topic
  Future<void> updateProgress(String topicId, double progress) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Update local data
      _progressData[topicId] = progress;
      notifyListeners();
      
      // Update in Firebase
      await _database
          .ref()
          .child('skillbench/users/${user.uid}/progress/$topicId')
          .set(progress);
    } catch (e) {
      print('Error updating progress for $topicId: $e');
      throw e;
    }
  }
  
  // Get progress for a specific topic (returns 0.0 if not found)
  double getProgressForTopic(String topicId) {
    return _progressData[topicId] ?? 0.0;
  }
  
  // Check if user has any progress for a given topic
  bool hasProgress(String topicId) {
    return _progressData.containsKey(topicId);
  }
  
  // Get all topics with progress
  List<String> getTopicsWithProgress() {
    return _progressData.keys.toList();
  }
  
  // Reset progress for a specific topic
  Future<void> resetProgress(String topicId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      // Remove from local data
      _progressData.remove(topicId);
      notifyListeners();
      
      // Remove from Firebase
      await _database
          .ref()
          .child('skillbench/users/${user.uid}/progress/$topicId')
          .remove();
    } catch (e) {
      print('Error resetting progress for $topicId: $e');
      throw e;
    }
  }
}