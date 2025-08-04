import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/progress_provider.dart';
import '../../screens/home/listtopics_screen.dart';
import '../../screens/academics/academics_screen.dart';

class OngoingProgramsWidget extends StatefulWidget {
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
  State<OngoingProgramsWidget> createState() => _OngoingProgramsWidgetState();
}

class _OngoingProgramsWidgetState extends State<OngoingProgramsWidget> {
  List<Map<String, dynamic>> _ongoingPrograms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use post frame callback to avoid calling Provider during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOngoingPrograms();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load programs when dependencies change (like when provider is ready)
    if (_ongoingPrograms.isEmpty && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOngoingPrograms();
      });
    }
  }

  Future<void> _loadOngoingPrograms() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);
      await progressProvider.refresh();

      // Get all progress data
      Map<String, Map<String, dynamic>> allProgress =
          progressProvider.allProgress;

      // Group by main topics
      Map<String, Map<String, dynamic>> groupedTopics = {};

      allProgress.forEach((topicId, progressData) {
        double progress =
            ((progressData['progress'] ?? 0.0) as num).toDouble() / 100.0;

        // Only include topics that have some progress
        if (progress > 0) {
          String categoryId = progressData['categoryId'] ?? '';
          String mainTopic = progressData['mainTopic'] ?? '';
          String subcategory = progressData['subcategory'] ?? '';
          String programmingLanguage =
              progressData['programmingLanguage'] ?? '';
          int lastUpdated = (progressData['lastUpdated'] ?? 0) as int;
          int bestScore = (progressData['bestScore'] ?? 0) as int;
          int totalQuestions = (progressData['totalQuestions'] ?? 0) as int;
          int totalCorrectAnswers =
              (progressData['totalCorrectAnswers'] ?? 0) as int;

          // Determine the display name and group key
          String displayName = '';
          String groupKey = '';

          // Priority: programmingLanguage > subcategory > mainTopic
          if (programmingLanguage.isNotEmpty) {
            displayName = programmingLanguage;
            groupKey = '${categoryId}_${programmingLanguage}';
          } else if (subcategory.isNotEmpty) {
            displayName = subcategory;
            groupKey = '${categoryId}_${subcategory}';
          } else if (mainTopic.isNotEmpty) {
            displayName = mainTopic;
            groupKey = '${categoryId}_${mainTopic}';
          } else {
            // Fallback to extracted name from topicId
            displayName = _extractTopicNameFromId(topicId);
            groupKey = '${categoryId}_${displayName}';
          }

          if (groupKey.isNotEmpty && displayName.isNotEmpty) {
            if (groupedTopics.containsKey(groupKey)) {
              // Aggregate the data
              var existing = groupedTopics[groupKey]!;

              // Calculate weighted average progress based on total questions
              int existingQuestions = (existing['totalQuestions'] ?? 0) as int;
              int newTotalQuestions = existingQuestions + totalQuestions;

              double existingProgress =
                  (existing['aggregatedProgress'] ?? 0.0) as double;
              double newProgress;

              if (newTotalQuestions > 0) {
                // Weighted average based on question count
                newProgress = ((existingProgress * existingQuestions) +
                        (progress * totalQuestions)) /
                    newTotalQuestions;
              } else {
                // Simple average if no question count available
                int subtopicCount = (existing['subtopicCount'] ?? 1) as int;
                newProgress = ((existingProgress * subtopicCount) + progress) /
                    (subtopicCount + 1);
              }

              existing['aggregatedProgress'] = newProgress;
              existing['totalQuestions'] = newTotalQuestions;
              existing['totalCorrectAnswers'] =
                  ((existing['totalCorrectAnswers'] ?? 0) as int) +
                      totalCorrectAnswers;
              existing['bestScore'] =
                  ((existing['bestScore'] ?? 0) as int) > bestScore
                      ? existing['bestScore']
                      : bestScore;
              existing['lastUpdated'] =
                  ((existing['lastUpdated'] ?? 0) as int) > lastUpdated
                      ? existing['lastUpdated']
                      : lastUpdated;
              existing['subtopicCount'] =
                  ((existing['subtopicCount'] ?? 1) as int) + 1;
            } else {
              // Create new entry
              groupedTopics[groupKey] = {
                'name': displayName,
                'categoryId': categoryId,
                'aggregatedProgress': progress,
                'icon': widget.getAssetForTopic(displayName),
                'color': widget.getColorForTopic(displayName),
                'lastUpdated': lastUpdated,
                'bestScore': bestScore,
                'totalQuestions': totalQuestions,
                'totalCorrectAnswers': totalCorrectAnswers,
                'groupKey': groupKey,
                'subtopicCount': 1,
                'originalTopicId':
                    topicId, // Keep one original ID for navigation
              };
            }
          }
        }
      });

      // Convert to list and sort by last updated
      List<Map<String, dynamic>> progressList = groupedTopics.values.toList();
      progressList.sort(
          (a, b) => (b['lastUpdated'] ?? 0).compareTo(a['lastUpdated'] ?? 0));

      setState(() {
        _ongoingPrograms = progressList.take(6).toList();
        _isLoading = false;
      });

      print(
          'Loaded ${_ongoingPrograms.length} grouped ongoing programs from Firebase');
    } catch (e) {
      print('Error loading ongoing programs: $e');
      // Fallback to default static data if Firebase fails
      _setDefaultPrograms();
    }
  }

  String _extractTopicNameFromId(String topicId) {
    // Handle different ID formats and extract readable topic names

    // Split by underscores and try to extract meaningful names
    List<String> parts = topicId.split('_');

    if (parts.length >= 3) {
      // New format: programminglanguage_c_cintroduction
      if (parts[0] == 'programminglanguage' || parts[0] == 'programming') {
        String language = parts[1];
        String topic = parts.length > 2 ? parts[2] : '';

        // Convert back to readable format
        return _convertToReadableFormat(language, topic);
      }

      // Academic format: academic_college_department_semester_subject_unit
      if (parts[0] == 'academic') {
        // Return the subject/unit part
        if (parts.length >= 6) {
          return _capitalizeWords(parts[4]); // subject
        } else if (parts.length >= 5) {
          return _capitalizeWords(parts[3]); // semester
        }
      }
    }

    // Legacy format handling
    if (topicId.contains('programming')) {
      List<String> programmingParts = topicId.split('_');
      for (int i = 1; i < programmingParts.length; i++) {
        String part = programmingParts[i];
        if (_isKnownProgrammingLanguage(part)) {
          return _capitalizeWords(part);
        }
      }
    }

    // Fallback: try to extract the most meaningful part
    String fallbackName = parts.length > 1 ? parts[1] : parts[0];
    return _capitalizeWords(fallbackName);
  }

  String _convertToReadableFormat(String language, String topic) {
    // Convert language codes to readable names
    Map<String, String> languageMap = {
      'c': 'C Programming',
      'cpp': 'C++',
      'java': 'Java',
      'python': 'Python',
      'javascript': 'JavaScript',
      'js': 'JavaScript',
      'kotlin': 'Kotlin',
      'swift': 'Swift',
      'flutter': 'Flutter',
      'react': 'React',
      'reactnative': 'React Native',
      'web': 'Web Development',
      'webdevelopment': 'Web Development',
      'aws': 'AWS',
      'azure': 'Azure',
      'gcp': 'Google Cloud',
      'html': 'HTML',
      'css': 'CSS',
    };

    String readableLanguage =
        languageMap[language.toLowerCase()] ?? _capitalizeWords(language);

    // If topic is just a repetition of language, return language only
    if (topic.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '') ==
        language.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      return readableLanguage;
    }

    // If topic contains meaningful additional info, include it
    if (topic.length > language.length + 2) {
      String readableTopic = _capitalizeWords(topic);
      return '$readableLanguage - $readableTopic';
    }

    return readableLanguage;
  }

  bool _isKnownProgrammingLanguage(String part) {
    List<String> knownLanguages = [
      'c',
      'cpp',
      'java',
      'python',
      'javascript',
      'js',
      'kotlin',
      'swift',
      'flutter',
      'react',
      'html',
      'css',
      'web',
      'aws',
      'azure'
    ];
    return knownLanguages.contains(part.toLowerCase());
  }

  String _capitalizeWords(String input) {
    if (input.isEmpty) return input;

    // Handle camelCase by adding spaces
    String spaced = input.replaceAllMapped(RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}');

    // Split by common separators and capitalize each word
    return spaced.split(RegExp(r'[_\s-]+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  void _setDefaultPrograms() {
    setState(() {
      _ongoingPrograms = [
        {
          'name': 'Web Development',
          'aggregatedProgress': 0.75,
          'icon': widget.getAssetForTopic('Web Development'),
          'color': widget.getColorForTopic('Web Development'),
          'categoryId': 'Web Development',
        },
        {
          'name': 'Python',
          'aggregatedProgress': 0.45,
          'icon': widget.getAssetForTopic('Python'),
          'color': widget.getColorForTopic('Python'),
          'categoryId': 'Programming Language',
        },
        {
          'name': 'Flutter',
          'aggregatedProgress': 0.60,
          'icon': widget.getAssetForTopic('Flutter'),
          'color': widget.getColorForTopic('Flutter'),
          'categoryId': 'App Development',
        },
      ];
      _isLoading = false;
    });
  }

  void _navigateToTopicScreen(Map<String, dynamic> program) {
    try {
      String categoryId = program['categoryId'] as String;
      String topicName = program['name'] as String;

      print('Navigating to category: $categoryId, topic: $topicName');

      // Navigate based on categoryId
      switch (categoryId) {
        case 'Programming Language':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListTopicsScreen(
                categoryName: 'Programming Language',
                categoryId: 'Programming Language',
                initialExpandedTopic: topicName,
              ),
            ),
          );
          break;

        case 'Web Development':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListTopicsScreen(
                categoryName: 'Web Development',
                categoryId: 'Web Development',
                initialExpandedTopic: topicName,
              ),
            ),
          );
          break;

        case 'App Development':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListTopicsScreen(
                categoryName: 'App Development',
                categoryId: 'App Development',
                initialExpandedTopic: topicName,
              ),
            ),
          );
          break;

        case 'Cloud Computing':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListTopicsScreen(
                categoryName: 'Cloud Computing',
                categoryId: 'Cloud Computing',
                initialExpandedTopic: topicName,
              ),
            ),
          );
          break;

        case 'General Skills':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListTopicsScreen(
                categoryName: 'General Skills',
                categoryId: 'General Skills',
                initialExpandedTopic: topicName,
              ),
            ),
          );
          break;

        default:
          // Check if it's an academic topic
          if (categoryId.toLowerCase().contains('academic') ||
              program.containsKey('originalTopicId') &&
                  (program['originalTopicId'] as String)
                      .startsWith('academic_')) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AcademicsScreen(),
              ),
            );
          } else {
            // Fallback: try to find matching category in categoryItems
            String? matchingCategory;
            widget.categoryItems.forEach((category, items) {
              if (category.toLowerCase() == categoryId.toLowerCase()) {
                matchingCategory = category;
              }
            });

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ListTopicsScreen(
                  categoryName: matchingCategory ?? categoryId,
                  categoryId: matchingCategory ?? categoryId,
                  initialExpandedTopic: topicName,
                ),
              ),
            );
          }
      }
    } catch (e) {
      print('Navigation error: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to navigate to topic'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProgressProvider>(
      builder: (context, progressProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Text(
                'Ongoing Programs',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Container(
              height: 162.h,
              child: _isLoading
                  ? _buildLoadingState()
                  : _ongoingPrograms.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(left: 20.w, right: 8.w),
                          itemCount: _ongoingPrograms.length,
                          itemBuilder: (context, index) {
                            return _buildProgramCard(_ongoingPrograms[index]);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        width: 180.w,
        height: 160.h,
        margin: EdgeInsets.only(left: 20.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromRGBO(237, 85, 100, 1),
                ),
                strokeWidth: 2,
              ),
              SizedBox(height: 8.h),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: 180.w,
        height: 160.h,
        margin: EdgeInsets.only(left: 20.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 40.sp,
                color: Colors.grey.shade400,
              ),
              SizedBox(height: 8.h),
              Text(
                'No Progress Yet',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'Start learning!',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program) {
    final double cardWidth = 180.w;
    final double cardHeight = 160.h;
    final double progressValue =
        (program['aggregatedProgress'] as double?) ?? 0.0;

    return GestureDetector(
        onTap: () => _navigateToTopicScreen(program),
        child: Container(
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
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 1.h),
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
                                          width: constraints.maxWidth *
                                              progressValue,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEB5B86),
                                            borderRadius:
                                                BorderRadius.circular(3.r),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildProgramIcon(Map<String, dynamic> program) {
    String iconPath = program['icon'] as String;

    return Image.asset(
      iconPath,
      width: 80.w, // Increased from 60.w
      height: 80.h, // Increased from 60.h
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 80.w, // Increased from 60.w
          height: 80.h, // Increased from 60.h
          decoration: BoxDecoration(
            color: (program['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.code,
            color: program['color'] as Color,
            size: 40.sp, // Increased from 30.sp
          ),
        );
      },
    );
  }
}
