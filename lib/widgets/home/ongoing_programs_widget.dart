import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class OngoingProgramsWidget extends StatelessWidget {
  final Map<String, List<Map<String, dynamic>>> categoryItems;
  final String Function(String) getAssetForTopic;
  final Color Function(String) getColorForTopic;

  const OngoingProgramsWidget({
    Key? key,
    required this.categoryItems,
    required this.getAssetForTopic,
    required this.getColorForTopic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> ongoingPrograms = [];
    
    List<double> progressValues = [0.75, 0.62, 0.38, 0.84, 0.29, 0.91];
    int progressIndex = 0;
    
    categoryItems.forEach((category, items) {
      for (var item in items.take(3)) {
        String itemName = item['name'] ?? 'Unknown';
        ongoingPrograms.add({
          'name': itemName,
          'progress': progressValues[progressIndex % progressValues.length],
          'icon': getAssetForTopic(itemName),
          'color': getColorForTopic(itemName),
        });
        progressIndex++;
        if (ongoingPrograms.length >= 3) break;
      }
      if (ongoingPrograms.length >= 3) return;
    });

    if (ongoingPrograms.isEmpty) {
      ongoingPrograms = [
        {
          'name': 'Web Development', 
          'progress': 0.75, 
          'icon': getAssetForTopic('Web Development'), 
          'color': getColorForTopic('Web Development')
        },
        {
          'name': 'Python', 
          'progress': 0.45, 
          'icon': getAssetForTopic('Python'), 
          'color': getColorForTopic('Python')
        },
        {
          'name': 'Flutter', 
          'progress': 0.60, 
          'icon': getAssetForTopic('Flutter'), 
          'color': getColorForTopic('Flutter')
        },
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ongoing Programs',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                "View all",
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Color.fromRGBO(237, 85, 100, 1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        Container(
          height: 162.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(left: 20.w, right: 8.w),
            itemCount: ongoingPrograms.length,
            itemBuilder: (context, index) {
              return _buildProgramCard(ongoingPrograms[index]);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildProgramCard(Map<String, dynamic> program) {
    final double cardWidth = 180.w;
    final double cardHeight = 160.h;
    final double progressValue = program['progress'] as double;

    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: EdgeInsets.only(right: 12.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(255, 253, 255, 1), 
            Color.fromRGBO(255, 244, 246, 1),
            Color.fromRGBO(255, 239, 243, 1),
            Color.fromRGBO(255, 233, 240, 1),
            Color.fromRGBO(255, 229, 237, 1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color.fromRGBO(239, 220, 240, 1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.w, 15.h, 10.w, 5.h),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _buildProgramIcon(program),
                    ),
                  ),
                  
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(top: 20.h),
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(252, 227, 234, 1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 5.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Row(
                                  children: [
                                    Container(
                                      width: constraints.maxWidth * progressValue,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEB5B86),
                                        borderRadius: BorderRadius.circular(3.r),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        
                        SizedBox(width: 8.w),
                        Text(
                          "${(progressValue * 100).toInt()}%",
                          style: TextStyle(
                            color: Color(0xFFEB5B86),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
            margin: EdgeInsets.fromLTRB(1.w, 1.h, 1.w, 1.h),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(255, 229, 237, 1),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Text(
              program['name'] as String,
              style: const TextStyle(
                color: Color(0xFF4A3960),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgramIcon(Map<String, dynamic> program) {
    String iconPath = program['icon'] as String;
    
    return Image.asset(
      iconPath,
      width: 60.w,
      height: 60.h,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 60.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: (program['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.code,
            color: program['color'] as Color,
            size: 30.sp,
          ),
        );
      },
    );
  }
}