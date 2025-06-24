import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/progress_provider.dart';
import '../global/mode_selection_card.dart';

class ListTopicsScreen extends StatefulWidget {
  final String categoryName;
  final String categoryId;
  final String? initialExpandedTopic;
  final String categoryIcon;
  
  const ListTopicsScreen({
    Key? key, 
    required this.categoryName,
    required this.categoryId,
    this.initialExpandedTopic,
    this.categoryIcon = '🌐',
  }) : super(key: key);

  @override
  State<ListTopicsScreen> createState() => _ListTopicsScreenState();
}

class _ListTopicsScreenState extends State<ListTopicsScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, bool> _expandedSubcategories = {};
  late ProgressProvider _progressProvider;
  bool _isLoading = true;
  List<String> _subcategories = [];
  Map<String, List<String>> _topicsBySubcategory = {};
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    _loadSubcategoriesAndTopics();
    _initializeAnimations();
  }
  
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSubcategoriesAndTopics() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadSubcategories();
      
      for (var subcategory in _subcategories) {
        _expandedSubcategories[subcategory] = subcategory == widget.initialExpandedTopic;
      }
      
      for (var subcategory in _subcategories) {
        await _loadTopicsForSubcategory(subcategory);
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading subcategories and topics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadSubcategories() async {
    try {
      DocumentSnapshot snapshot = await _firestore.doc('/prep/Title/${widget.categoryId}/${widget.categoryId}').get();
      
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        
        if (data.containsKey(widget.categoryId) && data[widget.categoryId] is List) {
          final List<dynamic> items = data[widget.categoryId];
          
          final List<String> subcategories = items.map((item) {
            if (item is Map) {
              return item['name'] as String? ?? 'Unknown';
            } else if (item is String) {
              return item;
            }
            return 'Unknown';
          }).toList();
          
          setState(() {
            _subcategories = subcategories;
          });
          
          print('Loaded subcategories for ${widget.categoryId}: $_subcategories');
        }
      }
    } catch (e) {
      print('Error loading subcategories for ${widget.categoryId}: $e');
    }
  }
  
  Future<void> _loadTopicsForSubcategory(String subcategory) async {
    try {
      final docRef = _firestore.doc('/prep/Title/${widget.categoryId}/${widget.categoryId}/$subcategory/Topics');
      final snapshot = await docRef.get();
      
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        
        if (data.containsKey('Topics') && data['Topics'] is List) {
          final List<dynamic> rawTopics = data['Topics'];
          final List<String> topics = rawTopics.map((topic) => topic.toString()).toList();
          
          setState(() {
            _topicsBySubcategory[subcategory] = topics;
          });
          
          print('Loaded topics for $subcategory: ${_topicsBySubcategory[subcategory]}');
        }
      } else {
        setState(() {
          _topicsBySubcategory[subcategory] = [];
        });
      }
    } catch (e) {
      print('Error loading topics for $subcategory: $e');
      setState(() {
        _topicsBySubcategory[subcategory] = [];
      });
    }
  }
  
  void _handleTopicSelection(String subcategory, String topic) {
    print('Topic selected: $topic in $subcategory from category: ${widget.categoryId}');
    
    ModeSelectionBottomSheet.show(
      context: context,
      topicName: topic,
      subcategoryName: subcategory,
      type: 'programming',
      categoryId: widget.categoryId,
      subcategory: subcategory,
      topic: topic,
      onPracticeModeSelected: () {
        print('Practice mode selected for $topic in $subcategory');
      },
      onTestModeSelected: () {
        print('Test mode selected for $topic in $subcategory');
      },
    );
  }
  
  double _calculateOverallProgress() {
    double totalProgress = 0;
    int totalTopics = 0;
    
    _subcategories.forEach((subcategory) {
      final topics = _topicsBySubcategory[subcategory] ?? [];
      
      topics.forEach((topic) {
        final topicId = '${widget.categoryId}_${subcategory}_${topic.replaceAll(' ', '_').toLowerCase()}';
        final progress = _progressProvider.getProgressForTopic(topicId);
        
        if (_progressProvider.hasProgress(topicId)) {
          totalProgress += progress;
          totalTopics++;
        }
      });
    });
    
    return totalTopics > 0 ? totalProgress / totalTopics : 0;
  }
  
  IconData _getCategoryIcon() {
    switch (widget.categoryId) {
      case 'Programming Language':
        return Icons.code;
      case 'Web Development':
        return Icons.web;
      case 'App Development':
        return Icons.smartphone;
      case 'Database':
        return Icons.storage;
      case 'UI/UX':
        return Icons.design_services;
      case 'Cloud Computing':
        return Icons.cloud;
      case 'DevOps':
        return Icons.integration_instructions;
      case 'Machine Learning':
        return Icons.psychology;
      default:
        return Icons.school;
    }
  }
  
  Color _getCategoryColor() {
    switch (widget.categoryId) {
      case 'Programming Language':
        return const Color(0xFF4A1E69);
      case 'Web Development':
        return const Color(0xFF2A6099);
      case 'App Development':
        return const Color(0xFF388E3C);
      case 'Database':
        return const Color(0xFF7B1FA2);
      case 'Cloud Computing':
        return const Color(0xFF0288D1);
      default:
        return const Color(0xFF4A1E69);
    }
  }
  
  Widget _buildCategoryHeader() {
    final overallProgress = _calculateOverallProgress();
    final overallProgressPercentage = (overallProgress * 100).toInt();
    final categoryColor = _getCategoryColor();
    final iconData = _getCategoryIcon();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 100, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      decoration: BoxDecoration(
        color: Color.fromRGBO(61, 21, 96, 1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 10,
                height: 32,
              ),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 0, right: 10),
                  child: Text(
                    widget.categoryName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(255, 214, 221, 1),
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 15),
          Padding(
            padding: EdgeInsets.only(left: 10),
            child: Container(
              width: 150,
              padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              decoration: BoxDecoration(
                color: Color.fromRGBO(94, 44, 138, 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 3),
                      child: Stack(
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: overallProgress,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Color.fromRGBO(234, 178, 68, 1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, right: 3),
                    child: Text(
                      '$overallProgressPercentage%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 18),
          Row(
            children: [
              SizedBox(width: 10),
              Icon(
                Icons.emoji_events,
                color: Colors.red[300],
                size: 22,
              ),
              SizedBox(width: 4),
              Text(
                'High Score:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color.fromRGBO(223, 103, 140, 1),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '450',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(
      effects: [
        FadeEffect(duration: 400.ms),
        SlideEffect(begin: const Offset(0, 0.2), duration: 400.ms),
      ],
    );
  }
  
  Widget _buildSubcategorySection(String subcategory) {
    final isExpanded = _expandedSubcategories[subcategory] ?? false;
    final topics = _topicsBySubcategory[subcategory] ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 1,
      shadowColor: Color.fromRGBO(253, 250, 254, 0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (!isExpanded) {
                  _loadTopicsForSubcategory(subcategory);
                }
                _expandedSubcategories[subcategory] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subcategory,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isExpanded 
                            ? Color.fromRGBO(223, 103, 140, 1)
                            : Color.fromRGBO(61, 21, 96, 1),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Color.fromRGBO(61, 21, 96, 1),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          AnimatedCrossFade(
            firstChild: Container(height: 0),
            secondChild: _buildTopicsListView(subcategory, topics),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    ).animate(effects: [FadeEffect(delay: 100.ms, duration: 400.ms)]);
  }
  
  Widget _buildTopicsListView(String subcategory, List<String> topics) {
    if (topics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No topics available',
          style: TextStyle(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children: topics.map((topic) => _buildTopicItem(subcategory, topic)).toList(),
      ),
    );
  }
  
  Widget _buildTopicItem(String subcategory, String topic) {
    final topicId = '${widget.categoryId}_${subcategory}_${topic.replaceAll(' ', '_').toLowerCase()}';
                    
    final progress = _progressProvider.getProgressForTopic(topicId);
    final percentage = (progress * 100).toInt();
    final hasProgress = _progressProvider.hasProgress(topicId);
    
    return InkWell(
      onTap: () => _handleTopicSelection(subcategory, topic),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color.fromRGBO(249, 248, 250, 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic,
              style: TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(61, 21, 96, 1),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(248, 241, 245, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 4),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.32,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: hasProgress ? progress : 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(219, 112, 147, 1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        hasProgress ? '$percentage%' : '0%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color.fromRGBO(61, 21, 96, 1),
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                  ),
                ),
                Expanded(child: Container()),
              ],
            ),
          ],
        ),
      ),
    ).animate(
      effects: [
        FadeEffect(delay: 100.ms, duration: 300.ms),
        SlideEffect(begin: const Offset(0, 0.05), duration: 300.ms),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No content available yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    ).animate(effects: [FadeEffect(duration: 500.ms)]);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(253, 251, 255, 1),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      body: Stack(
        children: [
          _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSubcategoriesAndTopics,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryHeader(),
                      SizedBox(height: 16),
                      
                      if (_subcategories.isEmpty)
                        _buildEmptyState()
                      else
                        ..._subcategories.map((subcategory) {
                          return _buildSubcategorySection(subcategory);
                        }).toList(),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
              
          Positioned(
            top: MediaQuery.of(context).padding.top + 30,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(
                Icons.arrow_back,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}