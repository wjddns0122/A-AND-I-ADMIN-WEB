import 'package:aandi_course_api/aandi_course_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/kst_datetime.dart';
import '../assignment_details_dialog.dart';
import '../task_management.dart';

class _D {
  static const textPrimary = Color(0xFF0F172B);
  static const textSub = Color(0xFF62748E);
  static const textLight = Color(0xFF90A1B9);
  static const sectionBorder = Color(0xFFE2E8F0);
  static const sectionBg = Color(0xFFF8FAFC);
  static const accentBlue = Color(0xFF155DFC);
}

class AssignmentsView extends ConsumerStatefulWidget {
  const AssignmentsView({
    super.key,
    required this.course,
    required this.isLoading,
    this.assignments,
  });

  final CourseSummary course;
  final bool isLoading;
  final List<Assignment>? assignments;

  @override
  ConsumerState<AssignmentsView> createState() => _AssignmentsViewState();
}

class _AssignmentsViewState extends ConsumerState<AssignmentsView> {
  final Set<int> _collapsedWeeks = {};

  @override
  Widget build(BuildContext context) {
    final assignments = widget.assignments;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          if (widget.isLoading && assignments == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (assignments == null || assignments.isEmpty)
            _buildEmptyState(context)
          else
            _buildAssignmentList(assignments),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _D.sectionBorder)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '과제 관리',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _D.textPrimary,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => context.go(
              '/dashboard/courses/${Uri.encodeComponent(widget.course.slug)}/assignments/new',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _D.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              '새 과제',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: _D.sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.assignment_outlined, size: 38, color: _D.textLight),
          const SizedBox(height: 12),
          const Text(
            '등록된 과제가 없습니다.',
            style: TextStyle(
              color: _D.textSub,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.go(
              '/dashboard/courses/${Uri.encodeComponent(widget.course.slug)}/assignments/new',
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('첫 과제 등록'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentList(List<Assignment> assignments) {
    final groupedMap = <int, List<Assignment>>{};
    for (final assignment in assignments) {
      groupedMap.update(
        assignment.weekNo,
        (list) => list..add(assignment),
        ifAbsent: () => [assignment],
      );
    }

    final sortedWeeks = groupedMap.keys.toList()..sort();

    return Column(
      children: sortedWeeks.map((week) {
        final weekData = groupedMap[week]!
          ..sort((a, b) => a.orderInWeek.compareTo(b.orderInWeek));
        final isCollapsed = _collapsedWeeks.contains(week);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (_collapsedWeeks.contains(week)) {
                    _collapsedWeeks.remove(week);
                  } else {
                    _collapsedWeeks.add(week);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_right_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _D.accentBlue,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _D.accentBlue.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$week주차',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _D.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '총 ${weekData.length}개',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _D.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(height: 4),
              ...weekData.map(
                (assignment) => _AssignmentCard(
                  assignment: assignment,
                  courseSlug: widget.course.slug,
                  ref: ref,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.courseSlug,
    required this.ref,
  });

  final Assignment assignment;
  final String courseSlug;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(assignment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${assignment.weekNo}주차 · ${assignment.metadata.title}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _D.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(label: assignment.status, color: statusColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '난이도: ${assignment.metadata.difficulty}  |  기한: ${apiIsoToDisplayKst(assignment.startAt)} ~ ${apiIsoToDisplayKst(assignment.endAt)}',
                style: const TextStyle(fontSize: 13, color: _D.textSub),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _CardTextButton(
                label: '조회',
                color: _D.accentBlue,
                onPressed: () => showAssignmentDetailsDialog(
                  context,
                  assignment,
                  courseSlug,
                ),
              ),
              _CardTextButton(
                label: '수정',
                color: _D.accentBlue,
                onPressed: () => context.go(
                  '/dashboard/courses/${Uri.encodeComponent(courseSlug)}/assignments/${Uri.encodeComponent(assignment.id)}/edit',
                ),
              ),
              _CardTextButton(
                label: '삭제',
                color: Colors.red,
                onPressed: () => _showDeleteDialog(context),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 12), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PUBLISHED':
        return const Color(0xFF7B1FA2);
      case 'DRAFT':
        return const Color(0xFF62748E);
      default:
        return const Color(0xFF62748E);
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '과제 삭제',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: const Text('이 과제와 관련 데이터를 모두 삭제합니다. 계속하시겠습니까?'),
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
                    TasksManagementAssignmentDeletedRequested(
                      courseSlug: courseSlug,
                      assignmentId: assignment.id,
                    ),
                  );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _CardTextButton extends StatelessWidget {
  const _CardTextButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
  }
}
