import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({Key? key}) : super(key: key);

  final List<Map<String, String>> faqList = const [
    {
      'question': 'What is Skill Bench?',
      'answer':
          'Skill Bench is an AI-powered quiz and learning platform for college students that personalizes learning paths, tracks progress, and generates quizzes using AI.'
    },
    {
      'question': 'How do I sign up?',
      'answer':
          'You can sign up using your phone number and OTP verification. After verifying, complete your profile with details like college, department, and batch.'
    },
    {
      'question': 'Can I change my profile picture?',
      'answer':
          'Yes, go to the Profile screen, tap your image, and either upload a custom image or choose from preset avatars.'
    },
    {
      'question': 'How is my data stored?',
      'answer':
          'Your data is securely stored in Firebase Firestore and Firebase Storage. All interactions are encrypted and protected by Firebase App Check.'
    },
    {
      'question': 'How do I report a bug?',
      'answer':
          'Go to the Settings screen and tap on "Report a Query" to submit your issue along with an optional screenshot.'
    },
    {
      'question': 'Can I view my progress?',
      'answer':
          'Yes, your quiz attempts and scores are saved and shown on your dashboard after login.'
    },
    {
      'question': 'Who can I contact for support?',
      'answer':
          'You can email us at support@skillbench.app or use the "Report Query" feature inside the app.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'FAQs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqList.length,
        itemBuilder: (context, index) {
          final faq = faqList[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                faq['question']!,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    faq['answer']!,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      height: 1.5,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
