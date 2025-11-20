import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tlucalendar/providers/exam_provider.dart';
import 'package:tlucalendar/providers/user_provider.dart';
import 'package:tlucalendar/models/api_response.dart';

class ExamScheduleScreen extends StatefulWidget {
  const ExamScheduleScreen({super.key});

  @override
  State<ExamScheduleScreen> createState() => _ExamScheduleScreenState();
}

class _ExamScheduleScreenState extends State<ExamScheduleScreen> {
  bool _hasInitialized = false;
  bool? _lastLoginState; // Track login state changes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasInitialized) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.isLoggedIn) {
          _loadExamSchedule();
          _loadAvailableSemesters();
          _hasInitialized = true;
          _lastLoginState = userProvider.isLoggedIn;
        }
      }
    });
  }

  Future<void> _loadAvailableSemesters() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    if (!userProvider.isLoggedIn) {
      return;
    }

    await examProvider.fetchAvailableSemesters(userProvider.accessToken!);
  }

  Future<void> _loadExamSchedule() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);

    if (!userProvider.isLoggedIn) {
      return;
    }

    final selectedSemester = userProvider.selectedSemester;
    if (selectedSemester == null) {
      return;
    }

    // Always try to load data, whether from cache or API
    // Check if we have cached data first
    final hasCache = await examProvider.hasRegisterPeriodsCache(selectedSemester.id);
    
    if (hasCache) {
      // Load from cache without API call
      await examProvider.selectSemesterFromCache(selectedSemester.id);
    } else {
      // No cache, fetch from API (will handle null token gracefully)
      await examProvider.selectSemester(
        userProvider.accessToken,
        selectedSemester.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, ExamProvider>(
      builder: (context, userProvider, examProvider, _) {
        // Check if login state changed and schedule reinitialize after build
        if (_lastLoginState != userProvider.isLoggedIn) {
          _lastLoginState = userProvider.isLoggedIn;
          _hasInitialized = false;
          
          // Schedule initialization for after the build completes
          if (userProvider.isLoggedIn && !_hasInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasInitialized) {
                _loadExamSchedule();
                _loadAvailableSemesters();
                _hasInitialized = true;
              }
            });
          }
        }
        
        if (!userProvider.isLoggedIn) {
          return _buildNotLoggedIn();
        }

        if (userProvider.selectedSemester == null) {
          return _buildNoSemesterSelected();
        }

        if (examProvider.isLoading) {
          return _buildLoading();
        }

        if (examProvider.errorMessage != null) {
          return _buildError(examProvider.errorMessage!, _loadExamSchedule);
        }

        // If no semester is selected yet in exam provider, show loading
        if (examProvider.selectedSemesterId == null) {
          return _buildLoading();
        }

        if (examProvider.registerPeriods.isEmpty) {
          return _buildNoExams();
        }

        return _buildExamSchedule(context, userProvider, examProvider);
      },
    );
  }

  Widget _buildExamSchedule(
    BuildContext context,
    UserProvider userProvider,
    ExamProvider examProvider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
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
        ),
        // Semester info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn học kỳ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (examProvider.isLoadingSemesters)
                      const Center(child: CircularProgressIndicator())
                    else if (examProvider.availableSemesters.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primaryContainer.withOpacity(0.6),
                              colorScheme.secondaryContainer.withOpacity(0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<int>(
                        value: examProvider.selectedSemesterId,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: colorScheme.primary,
                        ),
                        dropdownColor: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        items: examProvider.availableSemesters
                            .map(
                              (semester) {
                                final isSelected = semester.id == examProvider.selectedSemesterId;
                                return DropdownMenuItem<int>(
                                  value: semester.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          semester.semesterName,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 14,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (semester.isCurrent) ...[
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                colorScheme.tertiary,
                                                colorScheme.tertiary.withOpacity(0.8),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Hiện tại',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: colorScheme.onTertiary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value != null) {
                            await examProvider.selectSemester(
                              userProvider.accessToken,
                              value,
                            );
                          }
                        },
                      ),
                      )
                    else
                      Text(
                        userProvider.selectedSemester?.semesterName ??
                            'Không có học kỳ',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Register period filter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đợt học',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.6),
                            colorScheme.secondaryContainer.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<int>(
                      value: examProvider.selectedRegisterPeriodId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: colorScheme.primary,
                      ),
                      dropdownColor: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      items: examProvider.registerPeriods
                          .map(
                            (period) {
                              final isSelected = period.id == examProvider.selectedRegisterPeriodId;
                              return DropdownMenuItem<int>(
                                value: period.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        period.name,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null &&
                            examProvider.selectedSemesterId != null) {
                          // selectRegisterPeriod now handles fetching internally
                          examProvider.selectRegisterPeriod(
                            userProvider.accessToken,
                            examProvider.selectedSemesterId!,
                            value,
                            examProvider.selectedExamRound,
                          );
                        }
                      },
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Exam round selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lần thi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer.withOpacity(0.6),
                            colorScheme.secondaryContainer.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<int>(
                      value: examProvider.selectedExamRound,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: colorScheme.primary,
                      ),
                      dropdownColor: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      items: [1, 2, 3, 4, 5]
                          .map(
                            (round) {
                              final isSelected = round == examProvider.selectedExamRound;
                              return DropdownMenuItem<int>(
                                value: round,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        'Lần $round',
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null &&
                            examProvider.selectedSemesterId != null &&
                            examProvider.selectedRegisterPeriodId != null) {
                          examProvider.selectExamRound(value);
                          // Fetch exam room details when round changes
                          examProvider.fetchExamRoomDetails(
                            userProvider.accessToken,
                            examProvider.selectedSemesterId!,
                            examProvider.selectedRegisterPeriodId!,
                            value,
                          );
                        }
                      },
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Exam room details
        _buildExamRoomDetails(context, userProvider, examProvider),
      ],
    );
  }

  Widget _buildExamRoomDetails(
    BuildContext context,
    UserProvider userProvider,
    ExamProvider examProvider,
  ) {
    if (examProvider.isLoadingRooms) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
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
                      if (examProvider.selectedSemesterId != null &&
                          examProvider.selectedRegisterPeriodId != null) {
                        examProvider.fetchExamRoomDetails(
                          userProvider.accessToken!,
                          examProvider.selectedSemesterId!,
                          examProvider.selectedRegisterPeriodId!,
                          examProvider.selectedExamRound,
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
                      examProvider.fetchExamRoomDetails(
                        userProvider.accessToken!,
                        examProvider.selectedSemesterId!,
                        examProvider.selectedRegisterPeriodId!,
                        examProvider.selectedExamRound,
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
        return _buildExamRoomCard(context, examRoom, index);
      }, childCount: examProvider.examRooms.length),
    );
  }

  Widget _buildExamRoomCard(
    BuildContext context,
    StudentExamRoom examRoom,
    int index,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      key: ValueKey(examRoom.id), // Add unique key to preserve widget identity
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
                // Enhanced header with index badge
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
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                          if (examRoom.examCode != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SBD: ${examRoom.examCode}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                              ),
                            ),
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
                // Enhanced exam room details
                if (examRoom.examRoom != null) ...[
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
                    Icons.access_time,
                  ),
                  _buildDetailRow(
                    context,
                    'Giờ thi',
                    examRoom.examRoom!.examHour != null
                        ? '${examRoom.examRoom!.examHour!.startString ?? ''} - ${examRoom.examRoom!.examHour!.endString ?? ''}'
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.outline,
                            ),
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
              child: Icon(
                icon,
                size: 18,
                color: colorScheme.primary,
              ),
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

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa đăng nhập',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng đăng nhập để xem lịch thi',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSemesterSelected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa chọn học kỳ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng chọn học kỳ trong cài đặt',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildError(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Lỗi tải dữ liệu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoExams() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Không có lịch thi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa có lịch thi nào được công bố cho học kỳ này',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
