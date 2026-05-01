import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aandi_course_api/aandi_course_api.dart';
import 'package:go_router/go_router.dart';

import 'task_management.dart';
import 'views/enrollments_view.dart';
import 'views/assignments_view.dart';
import 'views/submission_statuses_view.dart';

// ─── 디자인 토큰 ────────────────────────────────────────────────────────────────
class _D {
  static const bg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172B);
  static const textSub = Color(0xFF62748E);
  static const textLight = Color(0xFF90A1B9);
  static const textDesc = Color(0xFF45556C);
  static const label = Color(0xFF314158);
  static const inputBorder = Color(0xFFCAD5E2);
  static const sectionBorder = Color(0xFFE2E8F0);
  static const accentBlue = Color(0xFF155DFC);

  // Badge
  static const badgeBasicBg = Color(0xFFE3F2FD);
  static const badgeBasicText = Color(0xFF1777D2);
  static const badgeFlBg = Color(0xFFFEF3E0);
  static const badgeFlText = Color(0xFFF67B00);
  static const badgePubBg = Color(0xFFF3E5F5);
  static const badgePubText = Color(0xFF7B1FA2);
  static const badgeDraftBg = Color(0xFFF0F0F0);
  static const badgeDraftText = Color(0xFF666666);
  static const badgeCsBg = Color(0xFFE8F5E9);
  static const badgeCsText = Color(0xFF2E7D32);
}

// ─── 진입 함수 ──────────────────────────────────────────────────────────────────
void showCourseDetailsDialog(BuildContext context, CourseSummary course) {
  context.go('/dashboard/courses/${Uri.encodeComponent(course.slug)}');
}

// ─── 상세 페이지 ────────────────────────────────────────────────────────────────
class CourseDetailsPage extends ConsumerStatefulWidget {
  final String courseSlug;

  const CourseDetailsPage({super.key, required this.courseSlug});

  @override
  ConsumerState<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends ConsumerState<CourseDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectionRequestedFor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CourseDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseSlug != widget.courseSlug) {
      _selectionRequestedFor = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksManagementBlocProvider);
    final course = _findCourse(state, widget.courseSlug);

    ref.listen(tasksManagementBlocProvider, (prev, next) {
      if (prev?.isDeleting == true && next.isDeleting == false) {
        if (next.errorMessage == null) {
          context.go('/dashboard');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('코스가 정상적으로 삭제되었습니다.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('코스 삭제 실패: ${next.errorMessage}')),
          );
        }
      }
      if (prev?.isCreating == true && next.isCreating == false) {
        if (next.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('수정 실패: ${next.errorMessage}')),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('성공적으로 반영되었습니다.')));
        }
      }
    });

    if (course == null) {
      return _buildCourseLoadingOrMissing(state);
    }

    _ensureCourseSelected(course, state);

    return Container(
      color: _D.bg,
      child: Column(
        children: [
          _DialogHeader(
            course: course,
            tabController: _tabController,
            isDeleting: state.isDeleting,
            onEditPressed: () => _showEditCourseDialog(context, ref, course),
            onDeletePressed: () => _showDeleteDialog(context, ref, course),
            onClose: () => context.go('/dashboard'),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                EnrollmentsView(
                  courseSlug: course.slug,
                  isLoading: state.isLoadingDetails,
                  enrollments: state.selectedCourseEnrollments,
                ),
                AssignmentsView(
                  course: course,
                  isLoading: state.isLoadingDetails,
                  assignments: state.selectedCourseAssignments,
                ),
                SubmissionStatusesView(
                  course: course,
                  isLoadingAssignments: state.isLoadingDetails,
                  assignments: state.selectedCourseAssignments,
                  statuses: state.selectedAssignmentSubmissionStatuses,
                  isLoadingStatuses: state.isLoadingSubmissionStatuses,
                  errorMessage: state.errorMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CourseSummary? _findCourse(TasksManagementState state, String courseSlug) {
    if (state.selectedCourse?.slug == courseSlug) {
      return state.selectedCourse;
    }

    for (final course in state.courses) {
      if (course.slug == courseSlug) {
        return course;
      }
    }
    return null;
  }

  void _ensureCourseSelected(CourseSummary course, TasksManagementState state) {
    if (state.selectedCourse?.slug == course.slug ||
        _selectionRequestedFor == course.slug) {
      return;
    }

    _selectionRequestedFor = course.slug;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(tasksManagementBlocProvider.notifier)
          .add(TasksManagementCourseSelected(course));
    });
  }

  Widget _buildCourseLoadingOrMissing(TasksManagementState state) {
    if (state.status == TasksManagementStatus.initial ||
        state.status == TasksManagementStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 42, color: _D.textLight),
            const SizedBox(height: 12),
            Text(
              '코스를 찾을 수 없습니다: ${widget.courseSlug}',
              style: const TextStyle(
                color: _D.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/dashboard'),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('과제 관리로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    CourseSummary course,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '코스 삭제',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: const Text(
          '정말로 이 코스를 삭제하시겠습니까?\n주차, 과제, 수강생 등의 모든 데이터가 함께 삭제되며 복구할 수 없습니다.',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: _D.textLight)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref
                  .read(tasksManagementBlocProvider.notifier)
                  .add(
                    TasksManagementCourseDeletedRequested(
                      courseSlug: course.slug,
                    ),
                  );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showEditCourseDialog(
    BuildContext context,
    WidgetRef ref,
    CourseSummary course,
  ) {
    final formKey = GlobalKey<FormState>();
    String title = course.metadata.title;
    String description = course.metadata.description ?? '';
    String phase = course.metadata.phase;
    String fieldTag = course.targetTrack;
    String status = course.status;
    String startDate = course.startDate ?? '';
    String endDate = course.endDate ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            '코스 수정',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormField(
                      label: '제목',
                      child: TextFormField(
                        initialValue: title,
                        decoration: _inputDeco('코스 제목'),
                        onSaved: (v) => title = v?.trim() ?? title,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      label: '설명',
                      child: TextFormField(
                        initialValue: description,
                        decoration: _inputDeco('코스 설명'),
                        maxLines: 2,
                        onSaved: (v) => description = v?.trim() ?? '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label: '단계 (Phase)',
                            child: DropdownButtonFormField<String>(
                              initialValue: phase,
                              decoration: _inputDeco(null),
                              items: const [
                                DropdownMenuItem(
                                  value: 'BASIC',
                                  child: Text('BASIC'),
                                ),
                                DropdownMenuItem(
                                  value: 'CS',
                                  child: Text('CS'),
                                ),
                                DropdownMenuItem(
                                  value: 'FRAMEWORK',
                                  child: Text('FRAMEWORK'),
                                ),
                              ],
                              onChanged: (v) => phase = v ?? phase,
                              onSaved: (v) => phase = v ?? phase,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            label: '트랙 (Track)',
                            child: DropdownButtonFormField<String>(
                              initialValue: fieldTag,
                              decoration: _inputDeco(null),
                              items: const [
                                DropdownMenuItem(
                                  value: 'FL',
                                  child: Text('FL'),
                                ),
                                DropdownMenuItem(
                                  value: 'SP',
                                  child: Text('SP'),
                                ),
                                DropdownMenuItem(
                                  value: 'NO',
                                  child: Text('NO'),
                                ),
                              ],
                              onChanged: (v) => fieldTag = v ?? fieldTag,
                              onSaved: (v) => fieldTag = v ?? fieldTag,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      label: '상태',
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: _inputDeco(null),
                        items: const [
                          DropdownMenuItem(
                            value: 'DRAFT',
                            child: Text('DRAFT'),
                          ),
                          DropdownMenuItem(
                            value: 'PUBLISHED',
                            child: Text('PUBLISHED'),
                          ),
                        ],
                        onChanged: (v) => status = v ?? status,
                        onSaved: (v) => status = v ?? status,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            label: '시작일',
                            child: _DatePickerInput(
                              initialValue: startDate,
                              placeholder: 'YYYY-MM-DD',
                              onChanged: (v) => startDate = v,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            label: '종료일',
                            child: _DatePickerInput(
                              initialValue: endDate,
                              placeholder: 'YYYY-MM-DD',
                              onChanged: (v) => endDate = v,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: _D.textLight)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _D.textPrimary),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  formKey.currentState?.save();
                  ref
                      .read(tasksManagementBlocProvider.notifier)
                      .add(
                        TasksManagementUpdateCourseRequested(
                          courseSlug: course.slug,
                          request: UpdateCourseRequest(
                            fieldTag: fieldTag,
                            startDate: startDate,
                            endDate: endDate,
                            title: title,
                            description: description,
                            phase: phase,
                            status: status,
                          ),
                        ),
                      );
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 다이얼로그 헤더 ─────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final CourseSummary course;
  final TabController tabController;
  final bool isDeleting;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.course,
    required this.tabController,
    required this.isDeleting,
    required this.onEditPressed,
    required this.onDeletePressed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _D.bg,
        border: Border(bottom: BorderSide(color: _D.sectionBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 제목 행 + 액션 버튼 ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 좌측: 제목 + 배지
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 + 배지들
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            course.metadata.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _D.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          _Badge.phase(course.metadata.phase),
                          _Badge.track(course.targetTrack),
                          _Badge.status(course.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 날짜 + 슬러그
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: _D.accentBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${course.startDate ?? '미정'} ~ ${course.endDate ?? '미정'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _D.textSub,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.link_rounded,
                            size: 14,
                            color: _D.accentBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            course.slug,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _D.textSub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '생성: ${course.createdAt?.toLocal().toString().split('.').first ?? '-'}  |  수정: ${course.updatedAt?.toLocal().toString().split('.').first ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _D.textLight,
                        ),
                      ),
                      if (course.metadata.description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        Text(
                          course.metadata.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: _D.textDesc,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 우측: 액션 버튼들
                Row(
                  children: [
                    _IconActionButton(
                      icon: Icons.edit_outlined,
                      onPressed: onEditPressed,
                    ),
                    const SizedBox(width: 4),
                    _IconActionButton(
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      isLoading: isDeleting,
                      onPressed: isDeleting ? null : onDeletePressed,
                    ),
                    const SizedBox(width: 4),
                    _IconActionButton(
                      icon: Icons.close_rounded,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── 탭 바 ─────────────────────────────────────────────────────────
          TabBar(
            controller: tabController,
            indicatorColor: _D.textPrimary,
            indicatorWeight: 3,
            labelColor: _D.textPrimary,
            unselectedLabelColor: _D.textSub,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.23,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            tabs: const [
              Tab(text: '수강생 목록'),
              Tab(text: '과제 관리'),
              Tab(text: '제출 현황'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 배지 ────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  factory _Badge.phase(String phase) {
    return _Badge(
      label: phase,
      bgColor: phase == 'CS'
          ? _D.badgeCsBg
          : phase == 'FRAMEWORK'
          ? const Color(0xFFFFF3E0)
          : _D.badgeBasicBg,
      textColor: phase == 'CS'
          ? _D.badgeCsText
          : phase == 'FRAMEWORK'
          ? const Color(0xFFE65100)
          : _D.badgeBasicText,
    );
  }

  factory _Badge.track(String track) {
    return _Badge(
      label: track,
      bgColor: _D.badgeFlBg,
      textColor: _D.badgeFlText,
    );
  }

  factory _Badge.status(String status) {
    return _Badge(
      label: status,
      bgColor: status == 'PUBLISHED' ? _D.badgePubBg : _D.badgeDraftBg,
      textColor: status == 'PUBLISHED' ? _D.badgePubText : _D.badgeDraftText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── 아이콘 액션 버튼 ─────────────────────────────────────────────────────────
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _IconActionButton({
    required this.icon,
    this.color,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18, color: color ?? _D.accentBlue),
        onPressed: onPressed,
      ),
    );
  }
}

// ─── 폼 레이블 래퍼 ──────────────────────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _D.label,
            letterSpacing: -0.15,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ─── 날짜 피커 인풋 ────────────────────────────────────────────────────────────
class _DatePickerInput extends StatefulWidget {
  final String initialValue;
  final String placeholder;
  final ValueChanged<String> onChanged;

  const _DatePickerInput({
    required this.initialValue,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  State<_DatePickerInput> createState() => _DatePickerInputState();
}

class _DatePickerInputState extends State<_DatePickerInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      readOnly: true,
      onTap: () async {
        final current = DateTime.tryParse(_ctrl.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2101),
        );
        if (picked != null) {
          final formatted =
              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          _ctrl.text = formatted;
          widget.onChanged(formatted);
        }
      },
      decoration: _inputDeco(widget.placeholder).copyWith(
        suffixIcon: const Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: _D.textLight,
        ),
      ),
    );
  }
}

// ─── 공통 InputDecoration ─────────────────────────────────────────────────────
InputDecoration _inputDeco(String? hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _D.textLight, fontSize: 14),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _D.inputBorder),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _D.inputBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _D.accentBlue, width: 1.5),
  ),
);
