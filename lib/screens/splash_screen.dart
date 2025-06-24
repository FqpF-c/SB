import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSplashScreen extends StatelessWidget {
  const CustomSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3D1560), // Dark purple background
      body: Stack(
        children: [
          // Top Rings (top-right aligned)
          Positioned(
            top: 0,
            right: 0,
            child: Image.asset(
              'assets/splash_screen/top_rings.png',
              width: 250,
            ),
          ),

          // Bottom Wave/Cloud
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/splash_screen/bottom_wave.png',
              fit: BoxFit.fill,
              height: 220,
            ),
          ),

          // Centered App Name
          Center(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.tiltWarp(fontSize: 32, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: 'Skill ',
                    style: GoogleFonts.tiltWarp(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: 'Bench',
                    style: GoogleFonts.tiltWarp(color: Color(0xFFE37A8E), fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
