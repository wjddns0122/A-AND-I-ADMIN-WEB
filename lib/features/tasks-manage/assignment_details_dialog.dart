import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aandi_course_api/aandi_course_api.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/python.dart';

import '../../core/utils/kst_datetime.dart';

// ─── 디자인 토큰 (EditAssignmentDialog와 일치시킴) ──────────────────────────────────
class _D {
  static const bg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172B);
  static const textLight = Color(0xFF90A1B9);
  static const textDesc = Color(0xFF45556C);
  static const sectionBorder = Color(0xFFE2E8F0);
  static const sectionBg = Color(0xFFF8FAFC);
  static const accentBlue = Color(0xFF155DFC);
}

// ─── 진입 함수 ──────────────────────────────────────────────────────────────────
void showAssignmentDetailsDialog(
  BuildContext context,
  Assignment assignment,
  String courseSlug,
) {
  showDialog(
    context: context,
    builder: (_) => _AssignmentDetailsDialog(
      assignment: assignment,
      courseSlug: courseSlug,
    ),
  );
}

// ─── 다이얼로그 위젯 ─────────────────────────────────────────────────────────────
class _AssignmentDetailsDialog extends ConsumerWidget {
  final Assignment assignment;
  final String courseSlug;

  const _AssignmentDetailsDialog({
    required this.assignment,
    required this.courseSlug,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: _D.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 1100,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            // 헤더
            _DialogHeader(
              title: '과제 상세 정보',
              onClose: () => Navigator.of(context).pop(),
            ),
            // 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 32, 40, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 기본 정보
                    _SectionHeader(
                      icon: Icons.info_outline_rounded,
                      title: '기본 정보',
                    ),
                    const SizedBox(height: 16),
                    _SectionContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _InfoItem(
                                label: '주차 / 순서',
                                value:
                                    '${assignment.weekNo}주차 / ${assignment.orderInWeek}',
                              ),
                              const SizedBox(width: 48),
                              _InfoItem(
                                label: '난이도',
                                value: assignment.metadata.difficulty,
                              ),
                              const SizedBox(width: 48),
                              _InfoItem(label: '상태', value: assignment.status),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '과제명',
                            style: TextStyle(
                              fontSize: 13,
                              color: _D.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assignment.metadata.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: _D.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '설명',
                            style: TextStyle(
                              fontSize: 13,
                              color: _D.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            assignment.metadata.description?.isNotEmpty == true
                                ? assignment.metadata.description!
                                : '등록된 설명이 없습니다.',
                            style: const TextStyle(
                              fontSize: 15,
                              color: _D.textDesc,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 2. 일정 설정
                    _SectionHeader(
                      icon: Icons.calendar_month_outlined,
                      title: '일정 설정',
                    ),
                    const SizedBox(height: 16),
                    _SectionContainer(
                      child: Row(
                        children: [
                          _InfoItem(
                            label: '시작 일시',
                            value: apiIsoToDisplayKst(assignment.startAt),
                          ),
                          const SizedBox(width: 48),
                          _InfoItem(
                            label: '종료 일시',
                            value: apiIsoToDisplayKst(assignment.endAt),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 3. 목표 및 요구사항
                    _SectionHeader(
                      icon: Icons.checklist_rounded,
                      title: '상세 목표 및 요구사항',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _DetailListCard(
                            title: '학습 목표',
                            items: assignment.metadata.learningGoals
                                .map((e) => e.learningGoalText)
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _DetailListCard(
                            title: '요구사항',
                            items: assignment.metadata.requirements
                                .map((e) => e.requirementText)
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 4. 테스트 케이스
                    _SectionHeader(
                      icon: Icons.science_outlined,
                      title: '테스트 케이스',
                    ),
                    const SizedBox(height: 16),
                    if (assignment.metadata.testCases.isEmpty)
                      const Text('등록된 테스트 케이스가 없습니다.')
                    else
                      ...assignment.metadata.testCases.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TestCaseViewCard(
                            index: e.key + 1,
                            tc: e.value,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // 5. 코드 템플릿
                    _SectionHeader(icon: Icons.code_rounded, title: '코드 템플릿'),
                    const SizedBox(height: 16),
                    if (assignment.metadata.codeTemplates.isEmpty)
                      const Text('등록된 코드 템플릿이 없습니다.')
                    else
                      ...assignment.metadata.codeTemplates.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _CodeTemplateViewCard(tmpl: e),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 내부 지원 컴포넌트 ─────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  const _DialogHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _D.sectionBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _D.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _D.accentBlue),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _D.accentBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _D.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final Widget child;
  const _SectionContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _D.textLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _D.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DetailListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _DetailListCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _D.sectionBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: items.isEmpty
                ? const Text(
                    '등록된 항목이 없습니다.',
                    style: TextStyle(color: _D.textLight, fontSize: 13),
                  )
                : Column(
                    children: items
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.circle,
                                    size: 5,
                                    color: _D.accentBlue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _D.textDesc,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TestCaseViewCard extends StatelessWidget {
  final int index;
  final AssignmentTestCase tc;
  const _TestCaseViewCard({required this.index, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _D.sectionBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '테스트케이스 #$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                _MetadataBadge(
                  label: tc.visibility.toString().split('.').last.toUpperCase(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '입력',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _D.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tc.inputValues.map((v) => v.toString()).join(' / '),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '기대 출력',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _D.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tc.outputText ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeTemplateViewCard extends StatefulWidget {
  final CodeTemplate tmpl;
  const _CodeTemplateViewCard({required this.tmpl});

  @override
  State<_CodeTemplateViewCard> createState() => _CodeTemplateViewCardState();
}

class _CodeTemplateViewCardState extends State<_CodeTemplateViewCard> {
  late CodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CodeController(
      text: widget.tmpl.functionTemplate ?? widget.tmpl.codeTemplate ?? '',
      language: _getHighlightLanguage(widget.tmpl.language),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _D.sectionBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 16,
                  color: _D.accentBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  '작성 템플릿: ${widget.tmpl.language}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 240,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: CodeTheme(
              data: const CodeThemeData(styles: atomOneLightTheme),
              child: SingleChildScrollView(
                child: CodeField(
                  controller: _controller,
                  readOnly: true,
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  dynamic _getHighlightLanguage(String lang) {
    final l = lang.toUpperCase();
    if (l == 'DART') return dart;
    if (l == 'KOTLIN') return kotlin;
    if (l == 'PYTHON') return python;
    return dart;
  }
}

class _MetadataBadge extends StatelessWidget {
  final String label;
  const _MetadataBadge({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.blue[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
