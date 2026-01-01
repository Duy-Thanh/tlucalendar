import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/providers/auth_provider.dart';
import 'package:tlucalendar/features/exam/data/models/exam_dtos.dart' as Legacy;
import 'package:tlucalendar/widgets/schedule_skeleton.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  bool _hasInitialized = false;
  bool? _lastLoginState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitialized) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.isLoggedIn) {
          _loadData();
          _hasInitialized = true;
          _lastLoginState = authProvider.isLoggedIn;
        }
      }
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    if (!authProvider.isLoggedIn || authProvider.accessToken == null) return;

    await examProvider.fetchAvailableSemesters(authProvider.accessToken!);

    if (examProvider.selectedSemesterId != null) {
      await _loadExamSchedule(examProvider.selectedSemesterId!);
    }
  }

  Future<void> _loadExamSchedule(int semesterId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) {
      return;
    }

    final hasCache = await examProvider.hasRegisterPeriodsCache(semesterId);

    if (hasCache) {
      await examProvider.selectSemesterFromCache(semesterId);
    } else {
      await examProvider.selectSemester(
        authProvider.accessToken!,
        semesterId,
        authProvider.rawTokenStr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ExamProvider>(
      builder: (context, authProvider, examProvider, _) {
        if (_lastLoginState != authProvider.isLoggedIn) {
          _lastLoginState = authProvider.isLoggedIn;
          _hasInitialized = false;

          if (authProvider.isLoggedIn && !_hasInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasInitialized) {
                _loadData();
                _hasInitialized = true;
              }
            });
          }
        }

        if (!authProvider.isLoggedIn) {
          // You said "buildNotLoggedIn" was calling "const Scaffold...", so I will inline it here
          // because I don't see the helper method in my small context window for overwrite.
          // But I'll assume I should just use the skeleton or empty state.
          return const Scaffold(
            body: Center(child: Text("Vui lòng đăng nhập")),
          );
        }

        if (examProvider.isLoadingSemesters) {
          return const Scaffold(body: SafeArea(child: ScheduleSkeleton()));
        }

        if (examProvider.errorMessage != null &&
            examProvider.availableSemesters.isEmpty) {
          return _buildError(examProvider.errorMessage!, _loadData);
        }

        if (examProvider.availableSemesters.isEmpty) {
          return const Scaffold(
            body: Center(child: Text("Không tìm thấy học kỳ nào")),
          );
        }

        if (examProvider.isLoading) {
          return const Scaffold(body: SafeArea(child: ScheduleSkeleton()));
        }

        if (examProvider.errorMessage != null &&
            examProvider.registerPeriods.isEmpty) {
          return _buildError(examProvider.errorMessage!, () async {
            if (examProvider.selectedSemesterId != null) {
              _loadExamSchedule(examProvider.selectedSemesterId!);
            } else {
              _loadData();
            }
          });
        }

        if (examProvider.registerPeriods.isEmpty && !examProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lịch thi')),
            body: _buildNoExams(),
          );
        }

        return _buildExamSchedule(context, authProvider, examProvider);
      },
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message),
            ElevatedButton(onPressed: onRetry, child: const Text("Thử lại")),
          ],
        ),
      ),
    );
  }

  Widget _buildNoExams() {
    return const Center(child: Text("Không có lịch thi"));
  }

  Widget _buildExamSchedule(
    BuildContext context,
    AuthProvider authProvider,
    ExamProvider examProvider,
  ) {
    final selectedSemesterName =
        examProvider.selectedSemester?.semesterName ?? 'Chọn học kỳ';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          elevation: 0,
          title: Text(
            'Lịch thi',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showFilterBottomSheet(context, examProvider, authProvider);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bộ lọc hiển thị',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$selectedSemesterName • Lần ${examProvider.selectedExamRound}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        if (examProvider.errorMessage != null)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      examProvider.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Exam room details
        _buildExamRoomDetails(context, authProvider, examProvider),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildExamRoomDetails(
    BuildContext context,
    AuthProvider authProvider,
    ExamProvider examProvider,
  ) {
    if (examProvider.isLoadingRooms) {
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(16), child: ScheduleSkeleton()),
      );
    }

    if (examProvider.roomErrorMessage != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    examProvider.roomErrorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (examProvider.selectedSemesterId != null &&
                          examProvider.selectedRegisterPeriodId != null) {
                        examProvider.fetchExamRoomDetails(
                          authProvider.accessToken!,
                          examProvider.selectedSemesterId!,
                          examProvider.selectedRegisterPeriodId!,
                          examProvider.selectedExamRound,
                          authProvider.rawTokenStr,
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (examProvider.examRooms.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có thông tin phòng thi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng chọn đợt học và lần thi',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (examProvider.selectedSemesterId != null &&
                    examProvider.selectedRegisterPeriodId != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      examProvider.fetchExamRoomDetails(
                        authProvider.accessToken!,
                        examProvider.selectedSemesterId!,
                        examProvider.selectedRegisterPeriodId!,
                        examProvider.selectedExamRound,
                        authProvider.rawTokenStr,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tải lại'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final examRoom = examProvider.examRooms[index];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: _buildExamRoomCard(context, examRoom, index),
            ),
          ),
        );
      }, childCount: examProvider.examRooms.length),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    ExamProvider examProvider,
    AuthProvider authProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<ExamProvider>(
          builder: (context, provider, _) {
            // Need to wrap in Consumer to listen to state changes inside the sheet
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bộ lọc lịch thi',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),

                      // 1. Semester Selector
                      Text(
                        'Học kỳ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: provider.selectedSemesterId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: provider.availableSemesters.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(
                              s.semesterName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            HapticFeedback.lightImpact();
                            // Update selected semester and reload
                            provider.selectSemester(
                              authProvider.accessToken!,
                              val,
                              authProvider.rawTokenStr,
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // 2. Register Period Selector
                      Text(
                        'Đợt học',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: provider.selectedRegisterPeriodId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: provider.registerPeriods.map((p) {
                          return DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null &&
                              provider.selectedSemesterId != null) {
                            HapticFeedback.lightImpact();
                            provider.selectRegisterPeriod(
                              authProvider.accessToken!,
                              provider.selectedSemesterId!,
                              val,
                              provider.selectedExamRound,
                              authProvider.rawTokenStr,
                            );
                          }
                        },
                      ),

                      const SizedBox(height: 24),

                      // 3. Exam Round Selector
                      Text(
                        'Lần thi',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Chips
                      Wrap(
                        spacing: 8,
                        children: [1, 2, 3, 4, 5].map((round) {
                          final isSelected =
                              round == provider.selectedExamRound;
                          return ChoiceChip(
                            label: Text('Lần $round'),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                HapticFeedback.lightImpact();
                                if (provider.selectedSemesterId != null &&
                                    provider.selectedRegisterPeriodId != null) {
                                  provider.selectExamRound(round);
                                  provider.fetchExamRoomDetails(
                                    authProvider.accessToken!,
                                    provider.selectedSemesterId!,
                                    provider.selectedRegisterPeriodId!,
                                    round,
                                    authProvider.rawTokenStr,
                                  );
                                }
                              }
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          child: const Text('Xong'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExamRoomCard(
    BuildContext context,
    Legacy.StudentExamRoom examRoom,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      key: ValueKey(examRoom.id),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.secondaryContainer.withOpacity(0.3),
                colorScheme.tertiaryContainer.withOpacity(0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'STT ${index + 1}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 12,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            examRoom.subjectName,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.1,
                                  fontSize: 15,
                                ),
                          ),
                          if (examRoom.studentCode != null) ...[
                            // Keep layout structure if needed, or just remove.
                            // Removing chip to avoid duplication as requested by plan.
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                if (examRoom.examRoom != null) ...[
                  _buildDetailRow(
                    context,
                    'Số báo danh',
                    examRoom.examCode ?? 'Chưa có',
                    Icons.badge,
                  ),
                  _buildDetailRow(
                    context,
                    'Ngày thi',
                    examRoom.examRoom!.examDateString ?? 'Chưa có',
                    Icons.calendar_today,
                  ),
                  _buildDetailRow(
                    context,
                    'Ca thi',
                    examRoom.examRoom!.examHour?.name ?? 'Chưa có',
                    Icons.layers_outlined,
                  ),
                  _buildDetailRow(
                    context,
                    'Giờ thi',
                    examRoom.examRoom!.examHour != null
                        ? '${examRoom.examRoom!.examHour!.startString} - ${examRoom.examRoom!.examHour!.endString}'
                        : 'Chưa có',
                    Icons.schedule,
                  ),
                  _buildDetailRow(
                    context,
                    'Phòng thi',
                    examRoom.examRoom!.room?.name ?? 'Chưa có',
                    Icons.room,
                  ),
                  if (examRoom.examRoom!.numberExpectedStudent != null)
                    _buildDetailRow(
                      context,
                      'Số sinh viên dự kiến',
                      '${examRoom.examRoom!.numberExpectedStudent}',
                      Icons.people,
                    ),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 40,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chưa có thông tin phòng thi',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
