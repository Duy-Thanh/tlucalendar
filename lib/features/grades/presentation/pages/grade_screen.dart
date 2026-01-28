import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/features/grades/domain/entities/student_mark.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/providers/grade_provider.dart';

class GradeScreen extends StatefulWidget {
  const GradeScreen({super.key});

  @override
  State<GradeScreen> createState() => _GradeScreenState();
}

class _GradeScreenState extends State<GradeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchGrades();
    });
  }

  Future<void> _fetchGrades() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final gradeProvider = Provider.of<GradeProvider>(context, listen: false);
    final token = authProvider.accessToken;
    if (token != null) {
      gradeProvider.fetchGrades(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra cứu điểm'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchGrades),
        ],
      ),
      body: Consumer<GradeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lỗi: ${provider.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchGrades,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final groupedGrades = provider.groupedGrades;
          if (groupedGrades.isEmpty) {
            return const Center(child: Text('Không có dữ liệu điểm.'));
          }

          // Sort semesters by name (descending usually implies newest first, but the string "Học kỳ 1 năm học 2024-2025" logic is tricky).
          // For now, keys order is insertion order from _grades list, which usually comes from API.
          // Let's assume API returns sensible order or just use keys.
          final semesterKeys = groupedGrades.keys.toList();

          return ListView.builder(
            itemCount: semesterKeys.length,
            padding: const EdgeInsets.all(8.0),
            itemBuilder: (context, index) {
              final semesterName = semesterKeys[index];
              final grades = groupedGrades[semesterName]!;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                  ),
                ),
                child: ExpansionTile(
                  key: PageStorageKey(semesterName),
                  title: Text(
                    semesterName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text('${grades.length} môn học'),
                  children: grades
                      .map((mark) => _buildGradeItem(mark))
                      .toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGradeItem(StudentMark mark) {
    final isPass =
        mark.charMark.isNotEmpty && mark.charMark.toUpperCase() != 'F';
    final evaluation = isPass ? "Đạt" : "Không đạt";
    final evaluationColor = isPass ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
          ),
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  mark.subjectName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (mark.charMark.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getColorForGrade(mark.charMark).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getColorForGrade(mark.charMark)),
                  ),
                  child: Text(
                    mark.charMark,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getColorForGrade(mark.charMark),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${mark.subjectCode} • ${mark.numberOfCredit} tín chỉ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Lần học: ${mark.studyTime} • Lần thi: ${mark.examRound} • ${mark.isCalculateMark ? "Tính điểm" : "Không tính điểm"}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildScoreColumn("QT", mark.markQT),
              _buildScoreColumn("Thi", mark.markTHI),
              _buildScoreColumn("Tổng kết", mark.mark, isBold: true),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Đánh giá",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    evaluation,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: evaluationColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreColumn(String label, double score, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          score.toString(),
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.blueAccent : null,
          ),
        ),
      ],
    );
  }

  Color _getColorForGrade(String charMark) {
    if (charMark.isEmpty) return Colors.grey;
    switch (charMark.toUpperCase()) {
      case 'A':
      case 'A+':
        return Colors.green;
      case 'B':
      case 'B+':
        return Colors.blue;
      case 'C':
      case 'C+':
        return Colors.orange;
      case 'D':
      case 'D+':
        return Colors.deepOrange;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
