import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class ReportQueryScreen extends StatefulWidget {
  const ReportQueryScreen({Key? key}) : super(key: key);

  @override
  State<ReportQueryScreen> createState() => _ReportQueryScreenState();
}

class _ReportQueryScreenState extends State<ReportQueryScreen> {
  final TextEditingController _controller = TextEditingController();
  File? _screenshot;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _screenshot = File(pickedFile.path));
    }
  }

  Future<void> _submitReport() async {
    final message = _controller.text.trim();
    if (message.isEmpty && _screenshot == null) return;

    setState(() => _isSubmitting = true);
    final String reportId = const Uuid().v4();
    String? imageUrl;

    try {
      if (_screenshot != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('bug_reports')
            .child('$reportId.jpg');

        final uploadTask = await ref.putFile(_screenshot!);
        imageUrl = await uploadTask.ref.getDownloadURL();
      }

      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await FirebaseDatabase.instance.ref('reports/$reportId').set({
        'message': message,
        'screenshot_url': imageUrl ?? '',
        'timestamp': timestamp,
      });

      setState(() {
        _controller.clear();
        _screenshot = null;
        _isSubmitting = false;
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Thank You!"),
          content: const Text("Your issue has been submitted to the developer."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
    } catch (e) {
      print("Error submitting report: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to submit. Please try again.")),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Report a Query"),
        backgroundColor: const Color(0xFFDF678C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Describe the bug or issue you're facing. Optionally, attach a screenshot to help us understand better.",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),

            // Issue Input Box with Border
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Write your issue here...",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFDF678C), width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Screenshot Preview
            if (_screenshot != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _screenshot!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.blueGrey),
                    onPressed: () => setState(() => _screenshot = null),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Gallery Button with Border
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined, color: Colors.black87),
                label: const Text(
                  "Add screenshot of query",
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDF678C),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? "Sending..." : "Send to Developer"),
            ),
          ],
        ),
      ),
    );
  }
}
