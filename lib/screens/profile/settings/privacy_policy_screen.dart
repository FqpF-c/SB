import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textStyle = GoogleFonts.roboto(
      fontSize: 16,
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      height: 1.6,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white), // back button color
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white, // title color
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last Updated: July 2025',
                style: textStyle.copyWith(fontWeight: FontWeight.w600)),

            const SizedBox(height: 20),

            Text(
              '1. Introduction',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Skill Bench ("we", "our", or "us") is committed to protecting your personal information. '
              'This Privacy Policy explains how we collect, use, and protect your data when you use our app.',
              style: textStyle,
            ),

            const SizedBox(height: 20),

            Text(
              '2. Data Collection',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'We collect the following data to provide and improve our services:\n'
              '• Phone number (via Firebase Authentication)\n'
              '• Name, email, college, department, and batch (during sign-up)\n'
              '• Profile image (custom or preset)\n'
              '• Quiz scores and progress\n'
              '• Bugs or feedback reported by users (including screenshots)',
              style: textStyle,
            ),

            const SizedBox(height: 20),

            Text(
              '3. Data Storage & Security',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'We use Firebase Firestore, Firebase Authentication, and Firebase Storage to securely store user data. '
              'All communication with our servers is encrypted. App integrity is protected using Firebase App Check.',
              style: textStyle,
            ),

            const SizedBox(height: 20),

            Text(
              '4. Third-party Services',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Our app integrates with third-party services like Firebase and a custom backend hosted on AWS EC2. '
              'We ensure these services comply with standard security practices.',
              style: textStyle,
            ),

            const SizedBox(height: 20),

            Text(
              '5. Your Rights',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'You have the right to request access, update, or delete your personal data. You can also contact us '
              'for any privacy concerns via the "Report Query" section in the Settings.',
              style: textStyle,
            ),

            const SizedBox(height: 20),

            Text(
              '6. Changes to this Policy',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'We may update this policy occasionally. Changes will be notified through the app or via your registered email.',
              style: textStyle,
            ),

            const SizedBox(height: 20),

            Text(
              '7. Contact Us',
              style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'For any questions or concerns, please contact our support team at:\n'
              'novelapps@smvec.ac.in',
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }
}
