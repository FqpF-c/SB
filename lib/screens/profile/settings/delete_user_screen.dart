import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class DeleteUserScreen extends StatefulWidget {
  const DeleteUserScreen({Key? key}) : super(key: key);

  @override
  State<DeleteUserScreen> createState() => _DeleteUserScreenState();
}

class _DeleteUserScreenState extends State<DeleteUserScreen> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitDeleteRequest() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _isSubmitting = true);
    final String requestId = const Uuid().v4();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      await FirebaseDatabase.instance.ref('delete_requests/$requestId').set({
        'reason': reason,
        'timestamp': timestamp,
      });

      setState(() {
        _reasonController.clear();
        _isSubmitting = false;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Request Received"),
          content: const Text(
            "Your account deletion request has been submitted. "
            "Please allow up to 48 working hours for it to be processed.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      print("Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to submit request. Try again.")),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color themeViolet = const Color(0xFFDF678C); // Violet theme color

    return Scaffold(
      appBar: AppBar(
        title: const Text("Delete Account"),
        backgroundColor: themeViolet,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "We're sorry to see you go. Your request will take up to 48 working hours to process.",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),

            const Text(
              "Reason for Deleting Account",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _reasonController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Write your reason here...",
                filled: true,
                fillColor: Colors.grey[200], // Grey background
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 24),

            Center(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitDeleteRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeViolet,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(
                  _isSubmitting ? "Submitting..." : "Submit Request",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
