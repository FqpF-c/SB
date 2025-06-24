import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/home/listtopics_screen.dart';

class ProgrammingLanguagesWidget extends StatefulWidget {
  final String Function(String) getAssetForTopic;
  final Color Function(String) getColorForTopic;

  const ProgrammingLanguagesWidget({
    Key? key,
    required this.getAssetForTopic,
    required this.getColorForTopic,
  }) : super(key: key);

  @override
  State<ProgrammingLanguagesWidget> createState() => _ProgrammingLanguagesWidgetState();
}

class _ProgrammingLanguagesWidgetState extends State<ProgrammingLanguagesWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> categoryTitles = [];
  Map<String, List<Map<String, dynamic>>> categoryItems = {};
  Map<String, String> displayTitles = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadCategoryTitles();
    await _loadDisplayTitles();
    await _loadAllCategoryItems();
    
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadCategoryTitles() async {
    try {
      final titlesDoc = await _firestore.doc('/prep/Title').get();
      
      if (titlesDoc.exists && titlesDoc.data() != null) {
        final data = titlesDoc.data()!;
        
        if (data.containsKey('Title') && data['Title'] is List) {
          final List<dynamic> titles = data['Title'];
          
          setState(() {
            categoryTitles = List<String>.from(titles);
          });
          
          print('Loaded category titles: $categoryTitles');
        }
      }
    } catch (e) {
      print('Error loading category titles: $e');
    }
  }

  Future<void> _loadDisplayTitles() async {
    try {
      final displayDoc = await _firestore.doc('/prep/TitleDisplay').get();
      
      if (displayDoc.exists && displayDoc.data() != null) {
        final data = displayDoc.data()!;
        
        Map<String, String> titles = {};
        
        for (String categoryId in categoryTitles) {
          if (data.containsKey(categoryId) && data[categoryId] is String) {
            titles[categoryId] = data[categoryId];
          } else {
            titles[categoryId] = categoryId;
          }
        }
        
        setState(() {
          displayTitles = titles;
        });
        
        print('Loaded display titles: $displayTitles');
      }
    } catch (e) {
      print('Error loading display titles: $e');
    }
  }

  Future<void> _loadAllCategoryItems() async {
    for (String categoryId in categoryTitles) {
      await _loadCategoryItems(categoryId);
    }
  }

  Future<void> _loadCategoryItems(String categoryId) async {
    try {
      final categoryItemsRef = _firestore.doc('/prep/Title/$categoryId/$categoryId');
      final docSnapshot = await categoryItemsRef.get();
      
      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        
        print('$categoryId document data: $data');
        
        if (data.containsKey(categoryId) && data[categoryId] is List) {
          final List<dynamic> rawItems = data[categoryId];
          print('Raw items for $categoryId: $rawItems');
          
          final List<Map<String, dynamic>> formattedItems = [];
          
          for (var item in rawItems) {
            String itemName;
            Map<String, dynamic> formattedItem;
            
            if (item is Map) {
              formattedItem = Map<String, dynamic>.from(item as Map);
              itemName = formattedItem['name'] ?? formattedItem.keys.first.toString();
            } else if (item is String) {
              itemName = item;
              formattedItem = {'name': itemName};
            } else {
              itemName = item.toString();
              formattedItem = {'name': itemName};
            }
            
            formattedItem['iconAsset'] = widget.getAssetForTopic(itemName);
            formattedItem['color'] = widget.getColorForTopic(itemName);
            
            if (!formattedItem.containsKey('name')) {
              formattedItem['name'] = itemName;
            }
            
            print('Item: $itemName -> Asset: ${formattedItem['iconAsset']}');
            
            formattedItems.add(formattedItem);
          }
          
          print('Formatted items for $categoryId: $formattedItems');
          
          if (mounted) {
            setState(() {
              categoryItems[categoryId] = formattedItems;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading items for $categoryId: $e');
    }
  }

  void _navigateToListTopics(BuildContext context, String categoryId, String? expandedTopic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListTopicsScreen(
          categoryName: displayTitles[categoryId] ?? categoryId,
          categoryId: categoryId,
          initialExpandedTopic: expandedTopic,
        ),
      ),
    );
  }

  List<Color> _getLanguageBackgroundGradient(String language) {
  List<Color> gradientColors = [
    const Color(0xFFEDE5F4),
    const Color(0xFFF9F5FF),
  ];
  
  switch (language.toLowerCase()) {
    case 'swift':
      gradientColors = [const Color(0xFFFFE0D5), const Color(0xFFFFF5F2)];
      break;
    case 'dart':
      gradientColors = [const Color(0xFFD6E8FF), const Color(0xFFF2F7FF)];
      break;
    case 'python':
      gradientColors = [const Color(0xFFD9EBFF), const Color(0xFFF5F9FF)];
      break;
    case 'javascript':
    case 'js':
      gradientColors = [const Color(0xFFFFF6D6), const Color(0xFFFFFDF5)];
      break;
    case 'java':
      gradientColors = [const Color(0xFFFFDDDD), const Color(0xFFFFF5F5)];
      break;
    case 'c#':
    case 'csharp':
      gradientColors = [const Color(0xFFEADDFF), const Color(0xFFF9F5FF)];
      break;
    case 'c++':
    case 'cpp':
      gradientColors = [const Color(0xFFD6EBFF), const Color(0xFFF2F8FF)];
      break;
    case 'c':
      gradientColors = [const Color(0xFFE0E7FF), const Color(0xFFF4F7FF)];
      break;
    case 'ruby':
      gradientColors = [const Color(0xFFFFDDE3), const Color(0xFFFFF5F7)];
      break;
    case 'go':
    case 'golang':
      gradientColors = [const Color(0xFFD6F5FA), const Color(0xFFF2FDFF)];
      break;
    case 'kotlin':
      gradientColors = [const Color(0xFFE4DDFF), const Color(0xFFF7F5FF)];
      break;
    case 'typescript':
      gradientColors = [const Color(0xFFD6E5F9), const Color(0xFFF2F8FF)];
      break;
    case 'php':
      gradientColors = [const Color(0xFFDDE1FF), const Color(0xFFF5F7FF)];
      break;
    case 'r':
      gradientColors = [const Color(0xFFDEEBFF), const Color(0xFFF7FAFF)];
      break;
    case 'html':
    case 'html5':
      gradientColors = [const Color(0xFFFFE8D9), const Color(0xFFFFF9F5)];
      break;
    case 'css':
    case 'css3':
      gradientColors = [const Color(0xFFD9F0FF), const Color(0xFFF5FAFF)];
      break;
    case 'react':
    case 'react.js':
      gradientColors = [const Color(0xFFD9F8FF), const Color(0xFFF4FDFF)];
      break;
    case 'angular':
      gradientColors = [const Color(0xFFFFDADA), const Color(0xFFFFF5F5)];
      break;
    case 'vue':
    case 'vue.js':
      gradientColors = [const Color(0xFFDFFCE9), const Color(0xFFF6FFF9)];
      break;
    case 'node':
    case 'node.js':
      gradientColors = [const Color(0xFFE2FFD9), const Color(0xFFF7FFF5)];
      break;
    case 'aws':
    case 'amazon web services':
      gradientColors = [const Color(0xFFFFECD6), const Color(0xFFFFF9F0)];
      break;
    case 'azure':
    case 'microsoft azure':
      gradientColors = [const Color(0xFFD6E5FF), const Color(0xFFF5F9FF)];
      break;
    case 'gcp':
    case 'google cloud':
      gradientColors = [const Color(0xFFF5E6FF), const Color(0xFFFBF5FF)];
      break;
    case 'docker':
      gradientColors = [const Color(0xFFD9F2FF), const Color(0xFFF5FBFF)];
      break;
    case 'kubernetes':
    case 'k8s':
      gradientColors = [const Color(0xFFD9EAFF), const Color(0xFFF5F9FF)];
      break;
    case 'android':
      gradientColors = [const Color(0xFFE5FFD9), const Color(0xFFF9FFF5)];
      break;
    case 'ios':
      gradientColors = [const Color(0xFFEBEBFF), const Color(0xFFF7F7FF)];
      break;
    case 'flutter':
      gradientColors = [const Color(0xFFD9EDFF), const Color(0xFFF5FAFF)];
      break;
    case 'react native':
      gradientColors = [const Color(0xFFD9F8FF), const Color(0xFFF4FDFF)];
      break;
    case 'xamarin':
      gradientColors = [const Color(0xFFD9E6FF), const Color(0xFFF5F9FF)];
      break;
    case 'ui/ux':
    case 'ui':
    case 'ux':
      gradientColors = [const Color(0xFFFBE2FF), const Color(0xFFFEF7FF)];
      break;
    case 'database':
    case 'sql':
      gradientColors = [const Color(0xFFE5E2FF), const Color(0xFFF9F8FF)];
      break;
    case 'devops':
      gradientColors = [const Color(0xFFFFE2DF), const Color(0xFFFFF7F6)];
      break;
    case 'machine learning':
    case 'ml':
    case 'ai':
      gradientColors = [const Color(0xFFE2F8FF), const Color(0xFFF7FDFF)];
      break;
    case 'data science':
      gradientColors = [const Color(0xFFE8E2FF), const Color(0xFFF9F7FF)];
      break;
    case 'blockchain':
      gradientColors = [const Color(0xFFFFEED9), const Color(0xFFFFFAF5)];
      break;
    case 'web development':
      gradientColors = [const Color(0xFFD9EEFF), const Color(0xFFF5FAFF)];
      break;
    case 'app development':
      gradientColors = [const Color(0xFFE0FFEC), const Color(0xFFF5FFF9)];
      break;
    case 'cloud computing':
      gradientColors = [const Color(0xFFE7F0FF), const Color(0xFFF9FBFF)];
      break;
    case 'general skills':
      gradientColors = [const Color(0xFFF5E8FF), const Color(0xFFFCF7FF)];
      break;
    case 'excel':
    case 'microsoft excel':
      gradientColors = [const Color(0xFFE8F5E8), const Color(0xFFF7FDF7)];
      break;
    case 'powerpoint':
    case 'microsoft powerpoint':
    case 'ppt':
      gradientColors = [const Color(0xFFFFE4D6), const Color(0xFFFFF7F2)];
      break;
  }
  
  return gradientColors;
}

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 200.h,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Column(
      children: categoryTitles.map((categoryId) {
        final items = categoryItems[categoryId] ?? [];
        
        if (items.isEmpty) {
          return const SizedBox();
        }
        
        final title = displayTitles[categoryId] ?? categoryId;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _navigateToListTopics(context, categoryId, null);
                    },
                    child: Text(
                      "View all",
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Color.fromRGBO(237, 85, 100, 1),
                        fontWeight: FontWeight.w500,
                      ),
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
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  
                  final String name = item['name'] ?? 'Unknown';
                  
                  final Color color = item['color'] is Color 
                      ? item['color'] as Color 
                      : widget.getColorForTopic(name);
                  
                  return SizedBox(
                    width: 185.w,
                    height: 142.h,
                    child: Padding(
                      padding: EdgeInsets.only(right: 12.w),
                      child: GestureDetector(
                        onTap: () {
                          _navigateToListTopics(context, categoryId, name);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _getLanguageBackgroundGradient(name),
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color.fromRGBO(246, 235, 247, 1),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildItemIcon(item['iconAsset'], color, name),
                              
                              SizedBox(height: 10.h),
                              
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.w),
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF341B58),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 15.h),
          ],
        );
      }).toList(),
    );
  }
  
  Widget _buildItemIcon(String? iconAsset, Color color, String itemName) {
    if (iconAsset != null && iconAsset.isNotEmpty && iconAsset != 'assets/icons/code_icon.png') {
      return Image.asset(
        iconAsset,
        width: 55.w,
        height: 55.h,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print('Failed to load item icon: $iconAsset for $itemName');
          return _getFallbackIcon(itemName, color);
        },
      );
    }
    
    return _getFallbackIcon(itemName, color);
  }
  
  Widget _getFallbackIcon(String itemName, Color color) {
  IconData iconData = Icons.code;
  Color iconColor = color;
  
  switch (itemName.toLowerCase()) {
    case 'java':
      iconData = Icons.coffee;
      iconColor = const Color(0xFFEF5350);
      break;
    case 'python':
      iconData = Icons.code;
      iconColor = const Color(0xFF66BB6A);
      break;
    case 'javascript':
    case 'js':
      iconData = Icons.javascript;
      iconColor = const Color(0xFFF7DF1E);
      break;
    case 'swift':
      iconData = Icons.sports_volleyball;
      iconColor = const Color(0xFFFF7043);
      break;
    case 'kotlin':
      iconData = Icons.hexagon;
      iconColor = const Color(0xFFAB47BC);
      break;
    case 'dart':
      iconData = Icons.timeline;
      iconColor = const Color(0xFF42A5F5);
      break;
    case 'c++':
    case 'cpp':
      iconData = Icons.data_object;
      iconColor = const Color(0xFF42A5F5);
      break;
    case 'c':
      iconData = Icons.code;
      iconColor = const Color(0xFF5C6BC0);
      break;
    case 'c#':
      iconData = Icons.tag;
      iconColor = const Color(0xFF9B4F96);
      break;
    case 'ruby':
      iconData = Icons.diamond;
      iconColor = const Color(0xFFCC342D);
      break;
    case 'go':
      iconData = Icons.pets;
      iconColor = const Color(0xFF00ADD8);
      break;
    case 'typescript':
      iconData = Icons.integration_instructions;
      iconColor = const Color(0xFF007ACC);
      break;
    case 'php':
      iconData = Icons.php;
      iconColor = const Color(0xFF777BB4);
      break;
    case 'r':
      iconData = Icons.bar_chart;
      iconColor = const Color(0xFF2266BB);
      break;
    case 'flutter':
      iconData = Icons.flutter_dash;
      iconColor = const Color(0xFF29B6F6);
      break;
    case 'react':
      iconData = Icons.web;
      iconColor = const Color(0xFF26C6DA);
      break;
    case 'web development':
      iconData = Icons.web;
      iconColor = const Color(0xFF26A69A);
      break;
    case 'aws':
      iconData = Icons.cloud;
      iconColor = const Color(0xFFFF9800);
      break;
    case 'azure':
      iconData = Icons.cloud;
      iconColor = const Color(0xFF0078D4);
      break;
    case 'google cloud':
    case 'gcp':
      iconData = Icons.cloud;
      iconColor = const Color(0xFF4285F4);
      break;
    case 'excel':
      iconData = Icons.table_chart;
      iconColor = const Color(0xFF4CAF50);
      break;
    case 'html':
    case 'html5':
      iconData = Icons.code;
      iconColor = const Color(0xFFE34F26);
      break;
    case 'css':
    case 'css3':
      iconData = Icons.style;
      iconColor = const Color(0xFF1572B6);
      break;
    case 'powerpoint':
    case 'microsoft powerpoint':
    case 'ppt':
      iconData = Icons.slideshow;
      iconColor = const Color(0xFFB7472A);
      break;
    default:
      iconData = Icons.code;
      iconColor = color;
  }
  
  return Icon(
    iconData,
    size: 55.sp,
    color: iconColor,
  );
}
}