import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_provider.dart';
import '../../theme/default_theme.dart';
import '../global/mode_selection_card.dart';

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({Key? key}) : super(key: key);

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? userCollege;
  
  List<String> departments = [];
  List<String> semesters = [];
  List<String> subjects = [];
  List<String> units = [];
  
  String? selectedDepartment;
  String? selectedSemester;
  String? selectedSubject;
  int? expandedSubjectIndex;
  
  bool isLoadingDepartments = false;
  bool isLoadingSemesters = false;
  bool isLoadingSubjects = false;
  bool isLoadingUnits = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  late ProgressProvider _progressProvider;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _progressProvider = Provider.of<ProgressProvider>(context, listen: false);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = await authProvider.getCurrentUserData();
      
      if (!mounted) return;
      
      if (userData != null && userData['college'] != null) {
        setState(() {
          userCollege = userData['college'];
        });
        await _loadDepartments();
      } else {
        _showErrorSnackBar('Unable to load user college information');
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading user data');
      }
    }
  }

  Future<void> _loadDepartments() async {
    if (userCollege == null || !mounted) return;
    
    setState(() {
      isLoadingDepartments = true;
      departments.clear();
      selectedDepartment = null;
      _clearSemesterData();
    });

    try {
      final docSnapshot = await _firestore
          .collection('colleges')
          .doc(userCollege)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('Departments')) {
          final departmentsList = List<String>.from(data['Departments'] ?? []);
          setState(() {
            departments = departmentsList;
            isLoadingDepartments = false;
          });
        } else {
          setState(() {
            isLoadingDepartments = false;
          });
          _showErrorSnackBar('No departments found for your college');
        }
      } else {
        setState(() {
          isLoadingDepartments = false;
        });
        _showErrorSnackBar('College data not found');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDepartments = false;
      });
      print('Error loading departments: $e');
      _showErrorSnackBar('Error loading departments');
    }
  }

  Future<void> _loadSemesters(String department) async {
    if (!mounted) return;
    
    setState(() {
      isLoadingSemesters = true;
      semesters.clear();
      selectedSemester = null;
      _clearSubjectData();
    });

    try {
      final docSnapshot = await _firestore
          .collection('colleges')
          .doc(userCollege)
          .collection('Departments')
          .doc(department)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('semesters')) {
          final semestersList = List<String>.from(data['semesters'] ?? []);
          setState(() {
            semesters = semestersList;
            isLoadingSemesters = false;
          });
        } else {
          setState(() {
            isLoadingSemesters = false;
          });
          _showErrorSnackBar('No semesters found for this department');
        }
      } else {
        setState(() {
          isLoadingSemesters = false;
        });
        _showErrorSnackBar('Department data not found');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingSemesters = false;
      });
      print('Error loading semesters: $e');
      _showErrorSnackBar('Error loading semesters');
    }
  }

  Future<void> _loadSubjects(String department, String semester) async {
    if (!mounted) return;
    
    setState(() {
      isLoadingSubjects = true;
      subjects.clear();
      selectedSubject = null;
      expandedSubjectIndex = null;
    });

    try {
      final docSnapshot = await _firestore
          .collection('colleges')
          .doc(userCollege)
          .collection('Departments')
          .doc(department)
          .collection('Semesters')
          .doc(semester)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('subjectList')) {
          final subjectsList = List<String>.from(data['subjectList'] ?? []);
          setState(() {
            subjects = subjectsList;
            isLoadingSubjects = false;
          });
        } else {
          setState(() {
            isLoadingSubjects = false;
          });
          _showErrorSnackBar('No subjects found for this semester');
        }
      } else {
        setState(() {
          isLoadingSubjects = false;
        });
        _showErrorSnackBar('Semester data not found');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingSubjects = false;
      });
      print('Error loading subjects: $e');
      _showErrorSnackBar('Error loading subjects');
    }
  }

  Future<void> _loadUnits(String subject, int subjectIndex) async {
    if (!mounted) return;
    
    setState(() {
      isLoadingUnits = true;
      units.clear();
      selectedSubject = subject;
    });

    try {
      final docSnapshot = await _firestore
          .collection('colleges')
          .doc(userCollege)
          .collection('Departments')
          .doc(selectedDepartment)
          .collection('Semesters')
          .doc(selectedSemester)
          .collection(subject)
          .doc('Units')
          .get();

      if (!mounted) return;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('Units')) {
          final unitsList = List<String>.from(data['Units'] ?? []);
          setState(() {
            units = unitsList;
            expandedSubjectIndex = subjectIndex;
            isLoadingUnits = false;
          });
        } else {
          setState(() {
            isLoadingUnits = false;
          });
          _showErrorSnackBar('No units found for this subject');
        }
      } else {
        setState(() {
          isLoadingUnits = false;
        });
        _showErrorSnackBar('Subject data not found');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingUnits = false;
      });
      print('Error loading units: $e');
      _showErrorSnackBar('Error loading units');
    }
  }

  void _clearSemesterData() {
    semesters.clear();
    selectedSemester = null;
    _clearSubjectData();
  }

  void _clearSubjectData() {
    subjects.clear();
    selectedSubject = null;
    expandedSubjectIndex = null;
    units.clear();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onUnitSelected(String unit) {
    ModeSelectionBottomSheet.show(
      context: context,
      topicName: selectedSubject ?? '',
      subcategoryName: unit,
      type: 'academic',
      quizParams: {
        'college': userCollege ?? '',
        'department': selectedDepartment ?? '',
        'semester': selectedSemester ?? '',
        'subject': selectedSubject ?? '',
        'unit': unit,
      },
      onPracticeModeSelected: () {
        print('Practice mode selected for: $selectedSubject - $unit');
      },
      onTestModeSelected: () {
        print('Test mode selected for: $selectedSubject - $unit');
      },
    );
  }

  String _generateUnitProgressId(String unit) {
    return 'academic_${userCollege ?? ''}_${selectedDepartment ?? ''}_${selectedSemester ?? ''}_${selectedSubject ?? ''}_$unit'
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .toLowerCase();
  }

  double _getUnitProgress(String unit) {
    final unitId = _generateUnitProgressId(unit);
    return _progressProvider.getProgressForTopic(unitId);
  }

  int _getUnitProgressPercentage(String unit) {
    final unitId = _generateUnitProgressId(unit);
    return _progressProvider.getProgressPercentage(unitId);
  }

  bool _hasUnitProgress(String unit) {
    final unitId = _generateUnitProgressId(unit);
    return _progressProvider.hasProgress(unitId);
  }

  double _getSubjectOverallProgress(String subject) {
    if (units.isEmpty) return 0.0;
    
    double totalProgress = 0.0;
    int progressCount = 0;
    
    for (String unit in units) {
      final unitId = _generateUnitProgressId(unit);
      if (_progressProvider.hasProgress(unitId)) {
        totalProgress += _progressProvider.getProgressForTopic(unitId);
        progressCount++;
      }
    }
    
    return progressCount > 0 ? totalProgress / progressCount : 0.0;
  }

  Widget _buildCategoryHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 80, 16, 12),
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
                    'Academics',
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
                  Icons.school,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Row(
            children: [
              SizedBox(width: 10),
              Icon(
                Icons.business,
                color: Colors.red[300],
                size: 22,
              ),
              SizedBox(width: 4),
              Text(
                'College:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  userCollege ?? 'Loading...',
                  style: TextStyle(
                    color: Color.fromRGBO(255, 214, 221, 1),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedDropdownSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 1,
      shadowColor: Color.fromRGBO(253, 250, 254, 0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Department & Semester',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color.fromRGBO(61, 21, 96, 1),
              ),
            ),
            SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color.fromRGBO(249, 248, 250, 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isLoadingDepartments
                  ? Container(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color.fromRGBO(219, 112, 147, 1),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Loading departments...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      isExpanded: true,
                      menuMaxHeight: 300,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.business,
                          color: Color.fromRGBO(219, 112, 147, 1),
                          size: 20,
                        ),
                      ),
                      hint: Text(
                        'Choose department',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      items: departments.map((String item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Container(
                            width: double.infinity,
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color.fromRGBO(61, 21, 96, 1),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          selectedDepartment = value;
                          _clearSemesterData();
                        });
                        if (value != null) {
                          _loadSemesters(value);
                        }
                      },
                      dropdownColor: Colors.white,
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Color.fromRGBO(219, 112, 147, 1),
                      ),
                    ),
            ),
            
            if (selectedDepartment != null) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(249, 248, 250, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isLoadingSemesters
                    ? Container(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromRGBO(219, 112, 147, 1),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Loading semesters...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: selectedSemester,
                        isExpanded: true,
                        menuMaxHeight: 300,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.calendar_today,
                            color: Color.fromRGBO(219, 112, 147, 1),
                            size: 20,
                          ),
                        ),
                        hint: Text(
                          'Choose semester',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        items: semesters.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Container(
                              width: double.infinity,
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color.fromRGBO(61, 21, 96, 1),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() {
                            selectedSemester = value;
                            _clearSubjectData();
                          });
                          if (value != null && selectedDepartment != null) {
                            _loadSubjects(selectedDepartment!, value);
                          }
                        },
                        dropdownColor: Colors.white,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(8),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Color.fromRGBO(219, 112, 147, 1),
                        ),
                      ),
        ),],
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsSection() {
    return Consumer<ProgressProvider>(
      builder: (context, progressProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoadingSubjects)
              _buildLoadingCard()
            else
              ...subjects.asMap().entries.map((entry) {
                final index = entry.key;
                final subject = entry.value;
                return _buildSubjectCard(subject, index);
              }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      elevation: 1,
      shadowColor: Color.fromRGBO(253, 250, 254, 0.1),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromRGBO(219, 112, 147, 1),
                ),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading subjects...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(String subject, int index) {
    final isExpanded = expandedSubjectIndex == index;
    final subjectProgress = isExpanded && units.isNotEmpty ? _getSubjectOverallProgress(subject) : 0.0;
    final subjectProgressPercentage = (subjectProgress * 100).round();
    
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
              if (isExpanded) {
                setState(() {
                  expandedSubjectIndex = null;
                  units.clear();
                });
              } else {
                _loadUnits(subject, index);
              }
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
                          subject,
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
                      if (isLoadingUnits && expandedSubjectIndex == index)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromRGBO(219, 112, 147, 1),
                            ),
                          ),
                        )
                      else
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
                  if (isExpanded && units.isNotEmpty) ...[
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
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: subjectProgress,
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
                            '$subjectProgressPercentage%',
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
            secondChild: _buildUnitsListView(units),
            crossFadeState: isExpanded && units.isNotEmpty
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitsListView(List<String> unitsList) {
    if (unitsList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No units available',
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
        children: unitsList.map((unit) => _buildUnitItem(unit)).toList(),
      ),
    );
  }

  Widget _buildUnitItem(String unit) {
    return Consumer<ProgressProvider>(
      builder: (context, progressProvider, child) {
        final progress = _getUnitProgress(unit);
        final percentage = _getUnitProgressPercentage(unit);
        final hasProgress = _hasUnitProgress(unit);
        
        return InkWell(
          onTap: () => _onUnitSelected(unit),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unit,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromRGBO(61, 21, 96, 1),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasProgress) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getProgressColor(progress),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getProgressIcon(progress),
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              _getProgressLabel(progress),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
                              widthFactor: progress,
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
                            '$percentage%',
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
        );
      },
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return Colors.green;
    if (progress >= 0.6) return Colors.orange;
    if (progress >= 0.3) return Colors.blue;
    return Colors.grey;
  }

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
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryHeader(),
                    SizedBox(height: 16),
                    
                    _buildCombinedDropdownSection(),
                    
                    if (selectedSemester != null && subjects.isNotEmpty)
                      _buildSubjectsSection(),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}