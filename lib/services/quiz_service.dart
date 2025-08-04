// Import Statements
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizService {
  static const String _programmingEndpoint = 'https://prepbackend.onesite.store/prep/generate-questions';
  static const String _academicEndpoint = 'https://prepbackend.onesite.store/quiz';

  // Firebase instance
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for prompt templates to avoid repeated Firebase calls
  static final Map<String, String> _templateCache = {};
  
  // Fallback prompt templates (in case Firebase fetch fails)
  static const Map<String, String> _fallbackTemplates = {
    'programming_practice': '''
Generate {count} multiple-choice questions about {programmingLanguage} focusing on {subTopic}.

Requirements:
- Questions should be practical and test real coding knowledge
- Include code snippets where appropriate
- Difficulty should be varied (easy, medium, hard)
- Each question must have exactly 4 options (A, B, C, D)
- Provide clear explanations for correct answers
- Include helpful hints for each question

Format each question as JSON with:
- "question": the question text
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": detailed explanation
- "difficulty": "easy", "medium", or "hard"
- "hint": helpful hint for solving

Focus on: {mainTopic} - {subTopic} in {programmingLanguage}
''',

    'programming_practice_adaptive': '''
Generate {count} adaptive multiple-choice questions about {programmingLanguage} focusing on {subTopic}.

Performance Analysis:
{performanceAnalysis}

Adaptive Requirements:
- Focus more on weak topics: {weakTopics}
- Reduce emphasis on strong topics: {strongTopics}
- Adjust difficulty based on overall accuracy: {overallAccuracy}%
- Consider time patterns: average {averageTime}s per question
- Include broader conceptual questions for weak areas
- Add advanced questions for strong areas

Generate questions that:
1. Address identified weaknesses with foundational concepts
2. Reinforce learning in problem areas
3. Challenge strengths with harder variations
4. Include cross-topic questions that combine weak and strong areas
5. Focus on practical application over memorization

Format each question as JSON with:
- "question": the question text (adaptive based on performance)
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": detailed explanation focusing on weak areas
- "difficulty": dynamically adjusted based on topic performance
- "hint": strategic hint for identified weak areas
- "topic": specific topic this question addresses
- "adaptive_reason": why this question was generated (weakness/strength reinforcement)

Focus on: {mainTopic} - {subTopic} in {programmingLanguage}
''',

    'programming_test': '''
Generate {count} challenging multiple-choice questions about {programmingLanguage} for assessment.

Requirements:
- Questions should test deep understanding of {subTopic}
- Include practical coding scenarios and problem-solving
- Mix of theoretical and practical questions
- Difficulty distribution: 30% easy, 50% medium, 20% hard
- Each question must have exactly 4 options
- Provide comprehensive explanations
- Include strategic hints

Format each question as JSON with:
- "question": the question text (can include code snippets)
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": detailed explanation with reasoning
- "difficulty": "easy", "medium", or "hard"
- "hint": strategic hint without giving away the answer

Topic: {mainTopic} - {subTopic} in {programmingLanguage}
Target: Assessment/Testing
''',

    'programming_test_adaptive': '''
Generate {count} adaptive test questions about {programmingLanguage} for the remaining portion of the assessment.

Performance Analysis from First 7 Questions:
{performanceAnalysis}

Adaptive Test Requirements:
- Address weak areas: {weakTopics} with focused questions
- Challenge strong areas: {strongTopics} with advanced concepts
- Overall accuracy so far: {overallAccuracy}%
- Recommended difficulty adjustment: {recommendedDifficulty}
- Time efficiency: {averageTime}s average

Generate the remaining test questions that:
1. Target identified weaknesses with remedial but challenging questions
2. Test mastery in strong areas with complex scenarios
3. Include integration questions combining multiple topics
4. Maintain assessment integrity while being adaptive
5. Scale difficulty appropriately for remaining test portion

Difficulty Distribution for Adaptive Questions:
- If accuracy < 60%: 50% easy, 40% medium, 10% hard
- If accuracy 60-80%: 30% easy, 50% medium, 20% hard  
- If accuracy > 80%: 20% easy, 40% medium, 40% hard

Format each question as JSON with:
- "question": the question text (adaptive difficulty)
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": detailed explanation
- "difficulty": adjusted based on performance
- "hint": helpful hint
- "topic": specific topic addressed
- "adaptive_reason": why this question was selected
- "is_adaptive": true

Topic: {mainTopic} - {subTopic} in {programmingLanguage}
Target: Adaptive Assessment
''',

    'academic_practice': '''
Generate {count} multiple-choice questions for {subject} - {unit}.

Requirements:
- Questions should cover key concepts in {unit}
- Suitable for {semester} semester students
- Include a mix of conceptual and application-based questions
- Difficulty should help in learning and practice
- Each question must have exactly 4 options
- Provide educational explanations
- Include learning hints

Format each question as JSON with:
- "question": the question text
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": educational explanation with additional context
- "difficulty": "easy", "medium", or "hard"
- "hint": learning hint to guide understanding

Subject: {subject}, Unit: {unit}
Academic Level: {semester} semester
Institution: {college}
''',

    'academic_practice_adaptive': '''
Generate {count} adaptive multiple-choice questions for {subject} - {unit}.

Performance Analysis:
{performanceAnalysis}

Adaptive Requirements for Academic Content:
- Weak topic areas: {weakTopics}
- Strong topic areas: {strongTopics}
- Overall comprehension: {overallAccuracy}%
- Learning pace: {averageTime}s per question

Generate questions that:
1. Reinforce weak conceptual areas with foundational questions
2. Build upon strong areas with application questions
3. Include interdisciplinary connections for better understanding
4. Focus on practical applications of theoretical concepts
5. Provide scaffolding for difficult topics

Format each question as JSON with:
- "question": the question text (adaptive to learning needs)
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": educational explanation focusing on weak areas
- "difficulty": adjusted for optimal learning
- "hint": learning hint for identified weak areas
- "topic": specific concept addressed
- "adaptive_reason": learning objective for this question

Subject: {subject}, Unit: {unit}
Academic Level: {semester} semester
Institution: {college}
''',

    'academic_test': '''
Generate {count} assessment questions for {subject} - {unit} examination.

Requirements:
- Questions should evaluate student understanding of {unit}
- Appropriate for {semester} semester examination level
- Include both theoretical and practical applications
- Difficulty suitable for formal assessment
- Each question must have exactly 4 options
- Provide detailed explanations for review
- Include helpful hints for learning

Format each question as JSON with:
- "question": the question text
- "options": array of 4 choices
- "correct_answer": the correct option
- "explanation": comprehensive explanation for learning
- "difficulty": "easy", "medium", or "hard"
- "hint": educational hint

Subject: {subject}, Unit: {unit}
Academic Level: {semester} semester, {college}
Purpose: Formal Assessment
''',
  };

  static Future<String> _fetchPromptTemplateFromFirebase({
    required String categoryId,
    required String subcategory,
    required String topic,
  }) async {
    final cacheKey = '${categoryId}_${subcategory}_${topic}';

    if (_templateCache.containsKey(cacheKey)) {
      return _templateCache[cacheKey]!;
    }

    try {
      final docRef = _firestore
          .collection('prep')
          .doc('Title')
          .collection(categoryId)
          .doc(categoryId)
          .collection(subcategory)
          .doc('Topics')
          .collection(topic)
          .doc('prompttemplate');

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey('prompttemplate') && data['prompttemplate'] != null) {
          final template = data['prompttemplate'].toString();
          _templateCache[cacheKey] = template;
          return template;
        }
      }
    } catch (e) {
      print('Error fetching template from Firebase: $e');
    }

    return '';
  }

  static Future<String> _getPromptTemplate({
    required String type,
    required String mode,
    String? categoryId,
    String? subcategory,
    String? topic,
    String? customPrompt,
    bool isAdaptive = false,
  }) async {
    if (customPrompt != null && customPrompt.isNotEmpty) return customPrompt;

    if (categoryId != null && subcategory != null && topic != null) {
      final firebaseTemplate = await _fetchPromptTemplateFromFirebase(
        categoryId: categoryId,
        subcategory: subcategory,
        topic: topic,
      );
      if (firebaseTemplate.isNotEmpty) return firebaseTemplate;
    }

    final templateKey = isAdaptive 
        ? '${type}_${mode}_adaptive'
        : '${type}_$mode';
    
    return _fallbackTemplates[templateKey] ?? _fallbackTemplates['programming_practice']!;
  }

  static String _fillPromptTemplate({
    required String template,
    required Map<String, dynamic> params,
    required int count,
    Map<String, dynamic>? performanceData,
  }) {
    String filled = template.replaceAll('{count}', count.toString());
    
    // Fill basic parameters
    params.forEach((k, v) => filled = filled.replaceAll('{$k}', v?.toString() ?? ''));
    
    // Fill performance analysis if provided
    if (performanceData != null && performanceData.isNotEmpty) {
      filled = filled.replaceAll('{performanceAnalysis}', json.encode(performanceData));
      filled = filled.replaceAll('{weakTopics}', (performanceData['weakTopics'] as List?)?.join(', ') ?? 'None identified');
      filled = filled.replaceAll('{strongTopics}', (performanceData['strongTopics'] as List?)?.join(', ') ?? 'None identified');
      filled = filled.replaceAll('{overallAccuracy}', (performanceData['overallAccuracy'] ?? 0).toString());
      filled = filled.replaceAll('{averageTime}', (performanceData['averageTime'] ?? 30).toString());
      filled = filled.replaceAll('{recommendedDifficulty}', performanceData['recommendedDifficulty'] ?? 'Medium');
    }
    
    return filled;
  }

  static Future<List<Map<String, dynamic>>> generateProgrammingQuestions({
    required String mainTopic,
    required String programmingLanguage,
    required String subTopic,
    int count = 10,
    int setCount = 0,
    String? customPrompt,
    String? modelType,
    String mode = 'practice',
    String? categoryId,
    String? subcategory,
    String? topic,
    Map<String, dynamic>? performanceData,
  }) async {
    final templateParams = {
      'mainTopic': mainTopic,
      'programmingLanguage': programmingLanguage,
      'subTopic': subTopic,
    };

    final isAdaptive = performanceData != null && performanceData.isNotEmpty;
    
    final baseTemplate = await _getPromptTemplate(
      type: 'programming',
      mode: mode,
      categoryId: categoryId,
      subcategory: subcategory,
      topic: topic,
      customPrompt: customPrompt,
      isAdaptive: isAdaptive,
    );

    final promptTemplate = _fillPromptTemplate(
      template: baseTemplate,
      params: templateParams,
      count: count,
      performanceData: performanceData,
    );

    final body = {
      'mainTopic': mainTopic,
      'programmingLanguage': programmingLanguage,
      'subTopic': subTopic,
      'count': count,
      'setCount': setCount,
      'promptTemplate': promptTemplate,
      'mode': mode,
      'isAdaptive': isAdaptive,
      'performanceData': performanceData,
      if (customPrompt != null) 'customPrompt': customPrompt,
      if (modelType != null) 'modelType': modelType,
      if (categoryId != null) 'categoryId': categoryId,
      if (subcategory != null) 'subcategory': subcategory,
      if (topic != null) 'topic': topic,
    };

    final response = await http.post(
      Uri.parse(_programmingEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    ).timeout(Duration(seconds: 90)); // Longer timeout for adaptive generation

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(data);
        
        // Mark adaptive questions
        if (isAdaptive) {
          for (var question in questions) {
            question['is_adaptive'] = true;
            question['generated_from_performance'] = true;
          }
        }
        
        return questions;
      }
      throw Exception('Invalid response format');
    } else {
      final error = json.decode(response.body);
      throw Exception('Server error: ${error['error'] ?? 'Unknown'}');
    }
  }

  static Future<List<Map<String, dynamic>>> generateAcademicQuestions({
    required String college,
    required String department,
    required String semester,
    required String subject,
    required String unit,
    int count = 10,
    int setCount = 0,
    String? customPrompt,
    String mode = 'practice',
    Map<String, dynamic>? performanceData,
  }) async {
    final templateParams = {
      'college': college,
      'department': department,
      'semester': semester,
      'subject': subject,
      'unit': unit,
    };

    final isAdaptive = performanceData != null && performanceData.isNotEmpty;

    final baseTemplate = await _getPromptTemplate(
      type: 'academic',
      mode: mode,
      customPrompt: customPrompt,
      isAdaptive: isAdaptive,
    );

    final promptTemplate = _fillPromptTemplate(
      template: baseTemplate,
      params: templateParams,
      count: count,
      performanceData: performanceData,
    );

    final body = {
      'college': college,
      'department': department,
      'semester': semester,
      'subject': subject,
      'unit': unit,
      'count': count,
      'setCount': setCount,
      'promptTemplate': promptTemplate,
      'mode': mode,
      'isAdaptive': isAdaptive,
      'performanceData': performanceData,
    };

    final response = await http.post(
      Uri.parse(_academicEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    ).timeout(Duration(seconds: 90));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['files'] != null && data['files'].isNotEmpty) {
        final content = data['files'][0]['content'];
        final parsed = json.decode(content);
        List<Map<String, dynamic>> questions = List<Map<String, dynamic>>.from(parsed['questions']);
        
        // Mark adaptive questions
        if (isAdaptive) {
          for (var question in questions) {
            question['is_adaptive'] = true;
            question['generated_from_performance'] = true;
          }
        }
        
        return questions;
      }
      throw Exception('Invalid response format');
    } else {
      final error = json.decode(response.body);
      throw Exception('Server error: ${error['error'] ?? 'Unknown'}');
    }
  }

  static Future<List<Map<String, dynamic>>> generatePracticeQuestions({
    required String type,
    required Map<String, dynamic> params,
  }) async {
    return (type == 'programming')
        ? await generateProgrammingQuestions(
            mainTopic: params['mainTopic'],
            programmingLanguage: params['programmingLanguage'],
            subTopic: params['subTopic'],
            count: 10,
            setCount: 0,
            mode: 'practice',
            categoryId: params['categoryId'],
            subcategory: params['subcategory'],
            topic: params['topic'],
          )
        : await generateAcademicQuestions(
            college: params['college'],
            department: params['department'],
            semester: params['semester'],
            subject: params['subject'],
            unit: params['unit'],
            count: 10,
            setCount: 0,
            mode: 'practice',
          );
  }

  static Future<List<Map<String, dynamic>>> generateTestQuestions({
    required String type,
    required Map<String, dynamic> params,
  }) async {
    final List<Map<String, dynamic>> allQuestions = [];

    final firstSet = (type == 'programming')
        ? await generateProgrammingQuestions(
            mainTopic: params['mainTopic'],
            programmingLanguage: params['programmingLanguage'],
            subTopic: params['subTopic'],
            count: 10,
            setCount: 0,
            mode: 'test',
            categoryId: params['categoryId'],
            subcategory: params['subcategory'],
            topic: params['topic'],
          )
        : await generateAcademicQuestions(
            college: params['college'],
            department: params['department'],
            semester: params['semester'],
            subject: params['subject'],
            unit: params['unit'],
            count: 10,
            setCount: 0,
            mode: 'test',
          );

    allQuestions.addAll(validateQuestions(firstSet));

    await Future.delayed(const Duration(seconds: 2));

    final secondSet = (type == 'programming')
        ? await generateProgrammingQuestions(
            mainTopic: params['mainTopic'],
            programmingLanguage: params['programmingLanguage'],
            subTopic: params['subTopic'],
            count: 10,
            setCount: 1,
            mode: 'test',
            categoryId: params['categoryId'],
            subcategory: params['subcategory'],
            topic: params['topic'],
          )
        : await generateAcademicQuestions(
            college: params['college'],
            department: params['department'],
            semester: params['semester'],
            subject: params['subject'],
            unit: params['unit'],
            count: 10,
            setCount: 1,
            mode: 'test',
          );

    allQuestions.addAll(validateQuestions(secondSet));

    return allQuestions;
  }

  // NEW: Generate adaptive questions for practice mode
  static Future<List<Map<String, dynamic>>> generateNextPracticeBatch({
    required String type,
    required Map<String, dynamic> params,
    int setCount = 1,
    Map<String, dynamic>? performanceData,
  }) async {
    return (type == 'programming')
        ? await generateProgrammingQuestions(
            mainTopic: params['mainTopic'],
            programmingLanguage: params['programmingLanguage'],
            subTopic: params['subTopic'],
            count: 10,
            setCount: setCount,
            mode: 'practice',
            categoryId: params['categoryId'],
            subcategory: params['subcategory'],
            topic: params['topic'],
            performanceData: performanceData, // Pass performance data for adaptive generation
          )
        : await generateAcademicQuestions(
            college: params['college'],
            department: params['department'],
            semester: params['semester'],
            subject: params['subject'],
            unit: params['unit'],
            count: 10,
            setCount: setCount,
            mode: 'practice',
            performanceData: performanceData, // Pass performance data for adaptive generation
          );
  }

  // NEW: Generate adaptive questions for test mode (remaining 12 questions after question 8)
  static Future<List<Map<String, dynamic>>> generateAdaptiveTestQuestions({
    required String type,
    required Map<String, dynamic> params,
    int count = 12,
    required Map<String, dynamic> performanceData,
  }) async {
    return (type == 'programming')
        ? await generateProgrammingQuestions(
            mainTopic: params['mainTopic'],
            programmingLanguage: params['programmingLanguage'],
            subTopic: params['subTopic'],
            count: count,
            setCount: 1, // This is the second set for test
            mode: 'test',
            categoryId: params['categoryId'],
            subcategory: params['subcategory'],
            topic: params['topic'],
            performanceData: performanceData, // Performance data from first 7 questions
          )
        : await generateAcademicQuestions(
            college: params['college'],
            department: params['department'],
            semester: params['semester'],
            subject: params['subject'],
            unit: params['unit'],
            count: count,
            setCount: 1,
            mode: 'test',
            performanceData: performanceData, // Performance data from first 7 questions
          );
  }

  static void clearTemplateCache() {
    _templateCache.clear();
  }

  static Future<bool> checkServerHealth(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse(endpoint.replaceAll('/generate-questions', '/health').replaceAll('/quiz', '/health')),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getUserDataForQuiz() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone_number') ?? '';
      return {
        'phone_number': phoneNumber,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (_) {
      return {
        'phone_number': 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  static bool isValidQuestion(Map<String, dynamic> question) {
    final requiredFields = ['question', 'options', 'correct_answer', 'explanation', 'difficulty', 'hint'];
    for (var field in requiredFields) {
      if (!question.containsKey(field)) return false;
    }
    return (question['options'] is List && question['options'].length == 4 &&
        question['options'].contains(question['correct_answer']));
  }

  static List<Map<String, dynamic>> validateQuestions(List<Map<String, dynamic>> questions) {
    return questions.where((q) => isValidQuestion(q)).toList();
  }
}