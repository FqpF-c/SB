import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ListTopicsScreenState extends State<ListTopicsScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, bool> _expandedSubcategories = {};
  final Map<String, double> _progressCache = {};
  final Map<String, int> _bestScoreCache = {};
  final Map<String, List<String>> _topicsBySubcategory = {};

  late ProgressProvider _progressProvider;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isInitialized = false;
  bool _isLoading = true;
  List<String> _subcategories = [];
  double? _cachedOverallProgress;
  int? _cachedBestScore;
  final Map<String, double> _subcategoryProgressCache = {};

  @override
  void initState() {
    super.initState();
    _progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    _initializeAnimations();
    _initializeData();
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

  void _initializeData() async {
    if (_isInitialized) return;

    try {
      await _loadSubcategoriesAndTopics();
      await _batchLoadProgressData();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _batchLoadProgressData() async {
    await _progressProvider.refresh();

    final List<String> allTopicIds = [];
    for (final subcategory in _subcategories) {
      final topics = _topicsBySubcategory[subcategory] ?? [];
      for (final topic in topics) {
        allTopicIds.add(_generateTopicProgressId(subcategory, topic));
      }
    }

    for (final topicId in allTopicIds) {
      _progressCache[topicId] = _progressProvider.getProgressForTopic(topicId);
      _bestScoreCache[topicId] = _progressProvider.getBestScore(topicId);
    }

    _precomputeAggregates();
  }

  void _precomputeAggregates() {
    double totalProgress = 0;
    int totalTopics = 0;
    int bestOverallScore = 0;

    for (final subcategory in _subcategories) {
      final topics = _topicsBySubcategory[subcategory] ?? [];
      double subcategoryTotal = 0;
      int subcategoryCount = 0;

      for (final topic in topics) {
        final topicId = _generateTopicProgressId(subcategory, topic);
        final progress = _progressCache[topicId] ?? 0.0;
        final score = _bestScoreCache[topicId] ?? 0;

        if (progress > 0) {
          totalProgress += progress;
          totalTopics++;
          subcategoryTotal += progress;
          subcategoryCount++;
        }

        if (score > bestOverallScore) {
          bestOverallScore = score;
        }
      }

      _subcategoryProgressCache[subcategory] =
          subcategoryCount > 0 ? subcategoryTotal / subcategoryCount : 0.0;
    }

    _cachedOverallProgress =
        totalTopics > 0 ? totalProgress / totalTopics : 0.0;
    _cachedBestScore = bestOverallScore;
  }

  Future<void> _loadSubcategoriesAndTopics() async {
    try {
      await _loadSubcategories();

      final futures = _subcategories.map((subcategory) async {
        _expandedSubcategories[subcategory] =
            subcategory == widget.initialExpandedTopic;
        await _loadTopicsForSubcategory(subcategory);
      });

      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error loading subcategories and topics: $e');
    }
  }

  Future<void> _loadSubcategories() async {
    try {
      final snapshot = await _firestore
          .doc('/prep/Title/${widget.categoryId}/${widget.categoryId}')
          .get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey(widget.categoryId) &&
            data[widget.categoryId] is List) {
          final List<dynamic> items = data[widget.categoryId];
          _subcategories = items.map((item) {
            if (item is Map) {
              return item['name'] as String? ?? 'Unknown';
            } else if (item is String) {
              return item;
            }
            return 'Unknown';
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading subcategories for ${widget.categoryId}: $e');
    }
  }

  Future<void> _loadTopicsForSubcategory(String subcategory) async {
    try {
      final docRef = _firestore.doc(
          '/prep/Title/${widget.categoryId}/${widget.categoryId}/$subcategory/Topics');
      final snapshot = await docRef.get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data.containsKey('Topics') && data['Topics'] is List) {
          final List<dynamic> rawTopics = data['Topics'];
          _topicsBySubcategory[subcategory] =
              rawTopics.map((topic) => topic.toString()).toList();
        }
      } else {
        _topicsBySubcategory[subcategory] = [];
      }
    } catch (e) {
      debugPrint('Error loading topics for $subcategory: $e');
      _topicsBySubcategory[subcategory] = [];
    }
  }

  void _handleTopicSelection(String subcategory, String topic) {
    ModeSelectionBottomSheet.show(
      context: context,
      topicName: topic,
      subcategoryName: subcategory,
      type: 'programming',
      categoryId: widget.categoryId,
      subcategory: subcategory,
      topic: topic,
      onPracticeModeSelected: () {},
      onTestModeSelected: () {},
    );
  }

  String _generateTopicProgressId(String subcategory, String topic) {
    String normalizeString(String input) {
      return input
          .replaceAll(' ', '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
    }

    final normalizedMainTopic = normalizeString(widget.categoryId);
    final normalizedSubtopic = normalizeString(subcategory);
    final normalizedTopic = normalizeString(topic);

    final primaryId =
        '${normalizedMainTopic}_${normalizedSubtopic}_${normalizedTopic}';

    if (_progressProvider.hasProgress(primaryId)) {
      return primaryId;
    }

    final altId1 =
        'programming_${normalizedSubtopic}_${normalizedSubtopic}_${normalizedTopic}';
    if (_progressProvider.hasProgress(altId1)) {
      return altId1;
    }

    final altId2 =
        'programming_${subcategory.toLowerCase().replaceAll(' ', '_')}_${topic.toLowerCase().replaceAll(' ', '_')}';
    if (_progressProvider.hasProgress(altId2)) {
      return altId2;
    }

    return primaryId;
  }

  double _getTopicProgress(String subcategory, String topic) {
    final topicId = _generateTopicProgressId(subcategory, topic);
    return _progressCache[topicId] ?? 0.0;
  }

  int _getTopicProgressPercentage(String subcategory, String topic) {
    return (_getTopicProgress(subcategory, topic) * 100).round();
  }

  bool _hasTopicProgress(String subcategory, String topic) {
    return _getTopicProgress(subcategory, topic) > 0;
  }

  int _getTopicBestScore(String subcategory, String topic) {
    final topicId = _generateTopicProgressId(subcategory, topic);
    return _bestScoreCache[topicId] ?? 0;
  }

  double _getOverallProgress() => _cachedOverallProgress ?? 0.0;
  int _getBestScore() => _cachedBestScore ?? 0;
  double _getSubcategoryProgress(String subcategory) =>
      _subcategoryProgressCache[subcategory] ?? 0.0;

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

  Widget _buildCategoryHeader() {
    final overallProgress = _getOverallProgress();
    final overallProgressPercentage = (overallProgress * 100).toInt();
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
              SizedBox(width: 10, height: 32),
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
                child: Icon(iconData, color: Colors.white, size: 36),
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
                          AnimatedFractionallySizedBox(
                            duration: Duration(milliseconds: 1000),
                            curve: Curves.easeInOut,
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
              Icon(Icons.emoji_events, color: Colors.red[300], size: 22),
              SizedBox(width: 4),
              Text(
                'Best Score:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Color.fromRGBO(223, 103, 140, 1),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_getBestScore()}%',
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
    final subcategoryProgress = _getSubcategoryProgress(subcategory);
    final subcategoryProgressPercentage = (subcategoryProgress * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 1,
      shadowColor: Color.fromRGBO(253, 250, 254, 0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedSubcategories[subcategory] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (topics.isNotEmpty && subcategoryProgress > 0) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(248, 241, 245, 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 4),
                          Container(
                            width: MediaQuery.of(context).size.width * 0.3,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: AnimatedFractionallySizedBox(
                              duration: Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                              alignment: Alignment.centerLeft,
                              widthFactor: subcategoryProgress,
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
                            '$subcategoryProgressPercentage%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color.fromRGBO(61, 21, 96, 1),
                            ),
                          ),
                          SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ],
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
        children:
            topics.map((topic) => _buildTopicItem(subcategory, topic)).toList(),
      ),
    );
  }

  Widget _buildTopicItem(String subcategory, String topic) {
    final progress = _getTopicProgress(subcategory, topic);
    final percentage = _getTopicProgressPercentage(subcategory, topic);
    final hasProgress = _hasTopicProgress(subcategory, topic);
    final bestScore = _getTopicBestScore(subcategory, topic);

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
            // Topic title row - removed progress status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic,
                    style: TextStyle(
                      fontSize: 16,
                      color: Color.fromRGBO(61, 21, 96, 1),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            // Simplified progress row
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
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.grey.shade100,
                              ),
                              AnimatedFractionallySizedBox(
                                duration: Duration(milliseconds: 1200),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color.fromRGBO(219, 112, 147, 1),
                                        Color.fromRGBO(219, 112, 147, 1)
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              if (progress > 0)
                                AnimatedFractionallySizedBox(
                                  duration: Duration(milliseconds: 1200),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress,
                                  child: Container(
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.0),
                                        ],
                                        stops: [0.0, 0.5, 1.0],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 35,
                        child: Text(
                          '$percentage%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: progress > 0
                                ? Color.fromRGBO(61, 21, 96, 1)
                                : Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                  ),
                ),
                // Removed the best score badge
                // Removed the status dot and expanded container
              ],
            ),
            // Removed the progress message section entirely
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

  List<Color> _getProgressGradient(double progress) {
    if (progress >= 0.8) return [Colors.green.shade400, Colors.green.shade600];
    if (progress >= 0.6)
      return [Colors.orange.shade400, Colors.orange.shade600];
    if (progress >= 0.3) return [Colors.blue.shade400, Colors.blue.shade600];
    return [Colors.grey.shade400, Colors.grey.shade600];
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.6) return Colors.orange;
    if (progress >= 0.3) return Colors.blue;
    return Colors.grey;
  }

  Color _getProgressStatusColor(double progress) => _getProgressColor(progress);

  IconData _getProgressIcon(double progress) {
    if (progress >= 0.8) return Icons.star;
    if (progress >= 0.6) return Icons.trending_up;
    if (progress >= 0.3) return Icons.play_arrow;
    return Icons.play_circle_outline;
  }

  String _getProgressLabel(double progress) {
    if (progress >= 0.8) return 'Mastered';
    if (progress >= 0.6) return 'Good';
    if (progress >= 0.3) return 'Learning';
    return 'Started';
  }

  String _getProgressMessage(double progress) {
    if (progress >= 0.8) return 'Excellent progress!';
    if (progress >= 0.6) return 'Great work!';
    return 'Keep going!';
  }

  Color _getBestScoreColor(int score) {
    if (score >= 90) return Color(0xFFFFD700).withOpacity(0.2);
    if (score >= 80) return Colors.amber.shade100;
    if (score >= 70) return Colors.orange.shade100;
    return Colors.blue.shade100;
  }

  Color _getBestScoreBorderColor(int score) {
    if (score >= 90) return Color(0xFFFFD700).withOpacity(0.6);
    if (score >= 80) return Colors.amber.shade300;
    if (score >= 70) return Colors.orange.shade300;
    return Colors.blue.shade300;
  }

  Color _getBestScoreTextColor(int score) {
    if (score >= 90) return Color(0xFFFFD700);
    if (score >= 80) return Colors.amber.shade700;
    if (score >= 70) return Colors.orange.shade700;
    return Colors.blue.shade700;
  }

  IconData _getBestScoreIcon(int score) {
    if (score >= 90) return Icons.emoji_events;
    if (score >= 80) return Icons.stars;
    if (score >= 70) return Icons.star;
    return Icons.star_border;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
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
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    ).animate(effects: [FadeEffect(duration: 500.ms)]);
  }

  Future<void> _refresh() async {
    _cachedOverallProgress = null;
    _cachedBestScore = null;
    _progressCache.clear();
    _bestScoreCache.clear();
    _subcategoryProgressCache.clear();

    await _batchLoadProgressData();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Color.fromRGBO(253, 251, 255, 1),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(0),
        child: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // Black icons
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(61, 21, 96, 1),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading topics...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: Color.fromRGBO(61, 21, 96, 1),
                  onRefresh: _refresh,
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
                          ..._subcategories
                              .map(_buildSubcategorySection)
                              .toList(),
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
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
