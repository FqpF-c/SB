import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class QuizService {
  // AWS endpoints for your Python scripts
  static const String _programmingEndpoint = 'https://prepbackend.onesite.store/prep/generate-questions';
  static const String _academicEndpoint = 'http://3.109.201.91:5000/quiz';
  
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

  // Fetch prompt template from Firebase
  static Future<String> _fetchPromptTemplateFromFirebase({
    required String categoryId,
    required String subcategory,
    required String topic,
  }) async {
    try {
      // Create cache key
      final cacheKey = '${categoryId}_${subcategory}_${topic}';
      
      // Check cache first
      if (_templateCache.containsKey(cacheKey)) {
        print('QUIZ_SERVICE: Using cached template for $cacheKey');
        return _templateCache[cacheKey]!;
      }
      
      print('QUIZ_SERVICE: Fetching template from Firebase...');
      print('Path: /prep/Title/$categoryId/$categoryId/$subcategory/Topics/$topic/prompttemplate');
      
      // Firebase path: prep/Title/{categoryId}/{categoryId}/{subcategory}/Topics/{topic}/prompttemplate/prompttemplate
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
          
          // Cache the template
          _templateCache[cacheKey] = template;
          
          print('QUIZ_SERVICE: Successfully fetched template from Firebase (${template.length} characters)');
          return template;
        } else {
          print('QUIZ_SERVICE: prompttemplate field not found in document');
        }
      } else {
        print('QUIZ_SERVICE: prompttemplate document does not exist');
      }
      
      // Return null if not found (will use fallback)
      return '';
    } catch (e) {
      print('QUIZ_SERVICE: Error fetching template from Firebase: $e');
      return '';
    }
  }

  // Get appropriate prompt template (Firebase first, then fallback)
  static Future<String> _getPromptTemplate({
    required String type,
    required String mode,
    String? categoryId,
    String? subcategory,
    String? topic,
    String? customPrompt,
  }) async {
    // If custom prompt is provided, use it
    if (customPrompt != null && customPrompt.isNotEmpty) {
      return customPrompt;
    }
    
    // Try to fetch from Firebase if we have the path parameters
    if (categoryId != null && subcategory != null && topic != null) {
      print('QUIZ_SERVICE: Attempting to fetch template from Firebase...');
      final firebaseTemplate = await _fetchPromptTemplateFromFirebase(
        categoryId: categoryId,
        subcategory: subcategory,
        topic: topic,
      );
      
      if (firebaseTemplate.isNotEmpty) {
        print('QUIZ_SERVICE: Using Firebase template');
        return firebaseTemplate;
      }
    }
    
    // Fallback to predefined templates
    print('QUIZ_SERVICE: Using fallback template for ${type}_$mode');
    final templateKey = '${type}_$mode';
    return _fallbackTemplates[templateKey] ?? _fallbackTemplates['programming_practice']!;
  }

  // Fill template with actual values
  static String _fillPromptTemplate({
    required String template,
    required Map<String, dynamic> params,
    required int count,
  }) {
    String filledTemplate = template.replaceAll('{count}', count.toString());
    
    // Replace all parameter placeholders
    params.forEach((key, value) {
      filledTemplate = filledTemplate.replaceAll('{$key}', value?.toString() ?? '');
    });
    
    return filledTemplate;
  }

  // Generate questions for Programming path
  static Future<List<Map<String, dynamic>>> generateProgrammingQuestions({
    required String mainTopic,
    required String programmingLanguage,
    required String subTopic,
    int count = 10,
    String? customPrompt,
    String? modelType,
    String mode = 'practice',
    // Firebase path parameters for template fetching
    String? categoryId,
    String? subcategory,
    String? topic,
  }) async {
    try {
      print('QUIZ_SERVICE: Generating programming questions...');
      print('Main Topic: $mainTopic, Language: $programmingLanguage, Sub Topic: $subTopic, Count: $count, Mode: $mode');
      
      // Get and fill the appropriate prompt template
      final templateParams = {
        'mainTopic': mainTopic,
        'programmingLanguage': programmingLanguage,
        'subTopic': subTopic,
      };
      
      final baseTemplate = await _getPromptTemplate(
        type: 'programming',
        mode: mode,
        categoryId: categoryId,
        subcategory: subcategory,
        topic: topic,
        customPrompt: customPrompt,
      );
      
      final promptTemplate = _fillPromptTemplate(
        template: baseTemplate,
        params: templateParams,
        count: count,
      );
      
      final requestBody = {
        'mainTopic': mainTopic,
        'programmingLanguage': programmingLanguage,
        'subTopic': subTopic,
        'count': count,
        'promptTemplate': promptTemplate,
        if (customPrompt != null) 'customPrompt': customPrompt,
        if (modelType != null) 'modelType': modelType,
        'mode': mode,
        // Include Firebase path info for backend reference
        if (categoryId != null) 'categoryId': categoryId,
        if (subcategory != null) 'subcategory': subcategory,
        if (topic != null) 'topic': topic,
      };
      
      print('QUIZ_SERVICE: Request body keys: ${requestBody.keys.toList()}');
      print('QUIZ_SERVICE: Prompt template length: ${promptTemplate.length} characters');
      
      final response = await http.post(
        Uri.parse(_programmingEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 60));
      
      print('QUIZ_SERVICE: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else {
          throw Exception('Invalid response format: expected array of questions');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Server error: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('QUIZ_SERVICE ERROR: $e');
      throw Exception('Failed to generate questions: $e');
    }
  }
  
  // Generate questions for Academic path
  static Future<List<Map<String, dynamic>>> generateAcademicQuestions({
    required String college,
    required String department,
    required String semester,
    required String subject,
    required String unit,
    int count = 10,
    String? customPrompt,
    String mode = 'practice',
  }) async {
    try {
      print('QUIZ_SERVICE: Generating academic questions...');
      print('College: $college, Department: $department, Semester: $semester, Subject: $subject, Unit: $unit, Count: $count, Mode: $mode');
      
      // For academic, we don't have the same Firebase structure, so use fallback templates
      final templateParams = {
        'college': college,
        'department': department,
        'semester': semester,
        'subject': subject,
        'unit': unit,
      };
      
      final baseTemplate = await _getPromptTemplate(
        type: 'academic',
        mode: mode,
        customPrompt: customPrompt,
      );
      
      final promptTemplate = _fillPromptTemplate(
        template: baseTemplate,
        params: templateParams,
        count: count,
      );
      
      final requestBody = {
        'college': college,
        'department': department,
        'semester': semester,
        'subject': subject,
        'unit': unit,
        'count': count,
        'promptTemplate': promptTemplate,
        'mode': mode,
      };
      
      print('QUIZ_SERVICE: Request body keys: ${requestBody.keys.toList()}');
      print('QUIZ_SERVICE: Prompt template length: ${promptTemplate.length} characters');
      
      final response = await http.post(
        Uri.parse(_academicEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: 60));
      
      print('QUIZ_SERVICE: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['files'] != null && data['files'].isNotEmpty) {
          final fileContent = data['files'][0]['content'];
          final questionsData = json.decode(fileContent);
          
          if (questionsData['questions'] != null) {
            return List<Map<String, dynamic>>.from(questionsData['questions']);
          } else {
            throw Exception('No questions found in response');
          }
        } else {
          throw Exception('Invalid response format: no files found');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Server error: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('QUIZ_SERVICE ERROR: $e');
      throw Exception('Failed to generate questions: $e');
    }
  }
  
  // Generate questions for Practice Mode (10 questions per request)
  static Future<List<Map<String, dynamic>>> generatePracticeQuestions({
    required String type,
    required Map<String, dynamic> params,
  }) async {
    try {
      List<Map<String, dynamic>> questions;
      
      if (type == 'programming') {
        questions = await generateProgrammingQuestions(
          mainTopic: params['mainTopic'],
          programmingLanguage: params['programmingLanguage'],
          subTopic: params['subTopic'],
          count: 10,
          mode: 'practice',
          categoryId: params['categoryId'],
          subcategory: params['subcategory'],
          topic: params['topic'],
        );
      } else {
        questions = await generateAcademicQuestions(
          college: params['college'],
          department: params['department'],
          semester: params['semester'],
          subject: params['subject'],
          unit: params['unit'],
          count: 10,
          mode: 'practice',
        );
      }
      
      return questions;
    } catch (e) {
      print('QUIZ_SERVICE: Error generating practice questions: $e');
      rethrow;
    }
  }
  
  // Generate questions for Test Mode (20 questions total - 2 separate API calls)
  static Future<List<Map<String, dynamic>>> generateTestQuestions({
    required String type,
    required Map<String, dynamic> params,
  }) async {
    try {
      List<Map<String, dynamic>> allQuestions = [];
      
      print('QUIZ_SERVICE: Generating test questions - First set of 10...');
      
      // Generate first set of 10 questions
      List<Map<String, dynamic>> firstSet;
      if (type == 'programming') {
        firstSet = await generateProgrammingQuestions(
          mainTopic: params['mainTopic'],
          programmingLanguage: params['programmingLanguage'],
          subTopic: params['subTopic'],
          count: 10,
          mode: 'test',
          categoryId: params['categoryId'],
          subcategory: params['subcategory'],
          topic: params['topic'],
        );
      } else {
        firstSet = await generateAcademicQuestions(
          college: params['college'],
          department: params['department'],
          semester: params['semester'],
          subject: params['subject'],
          unit: params['unit'],
          count: 10,
          mode: 'test',
        );
      }
      
      firstSet = validateQuestions(firstSet);
      if (firstSet.length < 8) {
        throw Exception('First set has insufficient valid questions: ${firstSet.length}/10');
      }
      
      allQuestions.addAll(firstSet);
      print('QUIZ_SERVICE: First set generated - ${firstSet.length} questions');
      
      // Small delay between API calls
      await Future.delayed(const Duration(seconds: 2));
      
      print('QUIZ_SERVICE: Generating test questions - Second set of 10...');
      
      // Generate second set of 10 questions
      List<Map<String, dynamic>> secondSet;
      if (type == 'programming') {
        secondSet = await generateProgrammingQuestions(
          mainTopic: params['mainTopic'],
          programmingLanguage: params['programmingLanguage'],
          subTopic: params['subTopic'],
          count: 10,
          mode: 'test',
          categoryId: params['categoryId'],
          subcategory: params['subcategory'],
          topic: params['topic'],
        );
      } else {
        secondSet = await generateAcademicQuestions(
          college: params['college'],
          department: params['department'],
          semester: params['semester'],
          subject: params['subject'],
          unit: params['unit'],
          count: 10,
          mode: 'test',
        );
      }
      
      secondSet = validateQuestions(secondSet);
      if (secondSet.length < 8) {
        throw Exception('Second set has insufficient valid questions: ${secondSet.length}/10');
      }
      
      allQuestions.addAll(secondSet);
      print('QUIZ_SERVICE: Second set generated - ${secondSet.length} questions');
      print('QUIZ_SERVICE: Total test questions generated: ${allQuestions.length}');
      
      if (allQuestions.length < 16) {
        throw Exception('Insufficient total questions for test mode: ${allQuestions.length}/20');
      }
      
      return allQuestions;
    } catch (e) {
      print('QUIZ_SERVICE: Error generating test questions: $e');
      rethrow;
    }
  }
  
  // Generate next batch of questions for practice mode
  static Future<List<Map<String, dynamic>>> generateNextPracticeBatch({
    required String type,
    required Map<String, dynamic> params,
  }) async {
    try {
      print('QUIZ_SERVICE: Generating next practice batch...');
      return await generatePracticeQuestions(
        type: type,
        params: params,
      );
    } catch (e) {
      print('QUIZ_SERVICE: Error generating next practice batch: $e');
      rethrow;
    }
  }

  // Clear template cache (useful for testing or when templates are updated)
  static void clearTemplateCache() {
    _templateCache.clear();
    print('QUIZ_SERVICE: Template cache cleared');
  }
  
  // Rest of the existing methods remain the same...
  static Future<bool> checkServerHealth(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${endpoint.replaceAll('/generate-questions', '/health').replaceAll('/quiz', '/health')}'),
      ).timeout(Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('QUIZ_SERVICE: Health check failed for $endpoint: $e');
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
    } catch (e) {
      print('QUIZ_SERVICE: Error getting user data: $e');
      return {
        'phone_number': 'unknown',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  static bool isValidQuestion(Map<String, dynamic> question) {
    final requiredFields = ['question', 'options', 'correct_answer', 'explanation', 'difficulty', 'hint'];
    
    for (String field in requiredFields) {
      if (!question.containsKey(field)) {
        print('QUIZ_SERVICE: Missing field: $field');
        return false;
      }
    }
    
    if (question['options'] is! List || question['options'].length != 4) {
      print('QUIZ_SERVICE: Invalid options format');
      return false;
    }
    
    if (!question['options'].contains(question['correct_answer'])) {
      print('QUIZ_SERVICE: Correct answer not in options');
      return false;
    }
    
    return true;
  }
  
  static List<Map<String, dynamic>> validateQuestions(List<Map<String, dynamic>> questions) {
    return questions.where((question) => isValidQuestion(question)).toList();
  }
}