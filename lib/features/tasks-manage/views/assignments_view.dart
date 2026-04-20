import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:aandi_course_api/aandi_course_api.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/json.dart';

import '../../../core/utils/kst_datetime.dart';
import '../task_management.dart';
import '../edit_assignment_dialog.dart';
import '../assignment_details_dialog.dart';

// ─── 디자인 토큰 ────────────────────────────────────────────────────────────────
class _D {
  static const textPrimary = Color(0xFF0F172B);
  static const textSub = Color(0xFF62748E);
  static const textLight = Color(0xFF90A1B9);
  static const label = Color(0xFF314158);
  static const inputBorder = Color(0xFFCAD5E2);
  static const sectionBorder = Color(0xFFE2E8F0);
  static const sectionBg = Color(0xFFF8FAFC);
  static const accentBlue = Color(0xFF155DFC);
}

InputDecoration _inputDeco(String? hint, {bool isTextarea = false}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _D.textLight, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTextarea ? 14 : 10,
      ),
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

// ─── 메인 위젯 ──────────────────────────────────────────────────────────────────
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
  final _formKey = GlobalKey<FormState>();

  // 기본 정보
  int _weekNo = 1;
  int _orderInWeek = 1;
  String _difficulty = 'LOW';
  String _title = '';
  String _description = '';
  String _startAt = '';
  String _endAt = '';

  // 학습 목표 / 요구사항
  final List<String> _learningGoals = [''];
  final List<String> _requirements = [''];

  // 테스트케이스
  final List<_TestCaseData> _testCases = [_TestCaseData()];

  // 코드 템플릿
  final List<_CodeTemplateData> _codeTemplates = [_CodeTemplateData()];

  bool _showAddForm = false;
  final Set<int> _collapsedWeeks = {};

  // JSON Mode 관련
  bool _isJsonMode = false;
  late CodeController _jsonController;
  String? _jsonError;

  @override
  void initState() {
    super.initState();
    _jsonController = CodeController(text: '', language: json);
  }

  @override
  void dispose() {
    for (var t in _codeTemplates) {
      t.dispose();
    }
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignments = widget.assignments;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 기존 과제 목록 ───────────────────────────────────────────────
          if (widget.isLoading && assignments == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (assignments == null || assignments.isEmpty)
            _buildEmptyState()
          else
            _buildAssignmentList(assignments),

          const SizedBox(height: 24),

          // ── 새 과제 추가 섹션 ───────────────────────────────────────────
          _buildAddFormHeader(),
          if (_showAddForm) ...[const SizedBox(height: 24), _buildAddForm()],
        ],
      ),
    );
  }

  // ── 빈 상태 ────────────────────────────────────────────────────────────────
  Widget _buildEmptyState() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      '등록된 과제가 없습니다.',
      style: TextStyle(color: _D.textLight, fontSize: 14),
    ),
  );

  // ── 과제 목록 ──────────────────────────────────────────────────────────────
  Widget _buildAssignmentList(List<Assignment> assignments) {
    if (assignments.isEmpty) return _buildEmptyState();

    // 1. 주차별 그룹화
    final groupedMap = <int, List<Assignment>>{};
    for (var a in assignments) {
      groupedMap.update(a.weekNo, (list) => list..add(a), ifAbsent: () => [a]);
    }

    // 2. 주차 순 정렬
    final sortedWeeks = groupedMap.keys.toList()..sort();

    return Column(
      children: sortedWeeks.map((week) {
        final weekData = groupedMap[week]!;
        // 주차 내에서는 순서(orderInWeek)대로 정렬
        weekData.sort((a, b) => a.orderInWeek.compareTo(b.orderInWeek));

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
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$week주차 ($week주차 과제 구성)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _D.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '총 ${weekData.length}개',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                (a) => _AssignmentCard(
                  assignment: a,
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

  // ── 폼 헤더 ─────────────────────────────────────────────────────────────────
  Widget _buildAddFormHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _D.sectionBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '새 과제 추가',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _D.textPrimary,
              letterSpacing: -0.89,
            ),
          ),
          _OutlineButton(
            icon: _showAddForm
                ? Icons.keyboard_arrow_up_rounded
                : Icons.add_rounded,
            label: _showAddForm ? '접기' : '폼 열기',
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
          ),
        ],
      ),
    );
  }

  // ── 전체 추가 폼 ─────────────────────────────────────────────────────────────
  Widget _buildAddForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 기본 정보
          _SectionHeader(icon: Icons.info_outline_rounded, title: '기본 정보'),
          const SizedBox(height: 12),
          _SectionContainer(
            child: Column(
              children: [
                // 주차 / 순서 / 난이도
                Row(
                  children: [
                    Expanded(
                      child: _buildLabeledField('주차 (Week)', _buildWeekField()),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildLabeledField(
                        '순서 (Order)',
                        _buildOrderField(),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: _buildLabeledField('난이도', _buildDifficultyField()),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLabeledField(
                  '과제 제목',
                  TextFormField(
                    decoration: _inputDeco('과제의 핵심 주제를 입력해주세요'),
                    onSaved: (v) => _title = v?.trim() ?? '',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '필수 항목입니다' : null,
                  ),
                ),
                const SizedBox(height: 20),
                _buildLabeledField(
                  '과제 설명',
                  TextFormField(
                    decoration: _inputDeco(
                      '과제에 대한 전반적인 설명을 작성해주세요',
                      isTextarea: true,
                    ),
                    maxLines: 5,
                    onSaved: (v) => _description = v?.trim() ?? '',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 2. 일정 설정
          _SectionHeader(icon: Icons.calendar_month_outlined, title: '일정 설정'),
          const SizedBox(height: 12),
          _SectionContainer(
            child: Row(
              children: [
                Expanded(
                  child: _buildLabeledField(
                    '시작 일시',
                    _DateTimePickerField(
                      initialValue: _startAt,
                      placeholder: '시작일시 (달력에서 선택)',
                      onChanged: (value) => setState(() => _startAt = value),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildLabeledField(
                    '종료 일시',
                    _DateTimePickerField(
                      initialValue: _endAt,
                      placeholder: '종료일시 (달력에서 선택)',
                      onChanged: (value) => setState(() => _endAt = value),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // 3. 상세 목표 및 요구사항
          _SectionHeader(icon: Icons.checklist_rounded, title: '상세 목표 및 요구사항'),
          const SizedBox(height: 12),
          _buildDynamicCard(
            title: '학습 목표',
            addLabel: '추가하기',
            items: _learningGoals,
            onAdd: () => setState(() => _learningGoals.add('')),
            onRemove: (i) => setState(() => _learningGoals.removeAt(i)),
            onChanged: (i, v) => _learningGoals[i] = v,
            placeholder: '학습 목표',
            multiline: false,
          ),
          const SizedBox(height: 12),
          _buildDynamicCard(
            title: '요구사항 (Requirements)',
            addLabel: '추가하기',
            items: _requirements,
            onAdd: () => setState(() => _requirements.add('')),
            onRemove: (i) => setState(() => _requirements.removeAt(i)),
            onChanged: (i, v) => _requirements[i] = v,
            placeholder: '요구사항',
            multiline: true,
          ),

          const SizedBox(height: 28),

          // 4. 테스트 예제
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(icon: Icons.science_outlined, title: '테스트 예제'),
              const SizedBox(width: 16),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _D.sectionBorder),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildModeToggleBtn('폼 입력', !_isJsonMode, () {
                      if (_isJsonMode) {
                        if (_syncFromJson()) {
                          setState(() => _isJsonMode = false);
                        }
                      }
                    }),
                    _buildModeToggleBtn('JSON 입력', _isJsonMode, () {
                      if (!_isJsonMode) {
                        _syncToJson();
                        setState(() => _isJsonMode = true);
                      }
                    }),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  if (_isJsonMode)
                    _OutlineButton(
                      icon: Icons.format_align_left_rounded,
                      label: 'JSON 포맷팅',
                      onPressed: _formatJson,
                    )
                  else ...[
                    _OutlineButton(
                      icon: Icons.add_rounded,
                      label: '테스트케이스 추가',
                      onPressed: () =>
                          setState(() => _testCases.add(_TestCaseData())),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isJsonMode)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildJsonEditor(),
                if (_jsonError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      _jsonError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            )
          else
            ..._testCases.asMap().entries.map((entry) {
              final i = entry.key;
              final tc = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTestCaseCard(i, tc),
              );
            }),

          const SizedBox(height: 28),

          // 5. 코드 템플릿
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(
                icon: Icons.code_rounded,
                title: '코드 템플릿 (Code Templates)',
              ),
              _OutlineButton(
                icon: Icons.add_rounded,
                label: '템플릿 추가',
                onPressed: () =>
                    setState(() => _codeTemplates.add(_CodeTemplateData())),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._codeTemplates.asMap().entries.map((entry) {
            final i = entry.key;
            final tmpl = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCodeTemplateCard(i, tmpl),
            );
          }),

          const SizedBox(height: 32),

          // 등록 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_isJsonMode) {
                  if (!_syncFromJson()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON 문법 오류를 먼저 해결해 주세요.')),
                    );
                    return;
                  }
                }
                if (!(_formKey.currentState?.validate() ?? false)) return;
                _formKey.currentState?.save();
                _submit();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _D.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '과제 등록',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekField() => TextFormField(
    initialValue: '1',
    decoration: _inputDeco('예: 1'),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSaved: (v) => _weekNo = int.tryParse(v ?? '1') ?? 1,
    validator: (v) => (v == null || v.trim().isEmpty) ? '필수' : null,
  );

  Widget _buildOrderField() => TextFormField(
    initialValue: '1',
    decoration: _inputDeco('예: 1'),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSaved: (v) => _orderInWeek = int.tryParse(v ?? '1') ?? 1,
    validator: (v) => (v == null || v.trim().isEmpty) ? '필수' : null,
  );

  Widget _buildDifficultyField() => DropdownButtonFormField<String>(
    initialValue: _difficulty,
    decoration: _inputDeco(null),
    items: const [
      DropdownMenuItem(value: 'LOW', child: Text('LOW')),
      DropdownMenuItem(value: 'MID', child: Text('MID')),
      DropdownMenuItem(value: 'HIGH', child: Text('HIGH')),
      DropdownMenuItem(value: 'VERY_HIGH', child: Text('VERY_HIGH')),
    ],
    onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
    onSaved: (v) => _difficulty = v ?? _difficulty,
  );

  Widget _buildLabeledField(String label, Widget field) => Column(
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
      field,
    ],
  );

  Widget _buildDynamicCard({
    required String title,
    required String addLabel,
    required List<String> items,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required Function(int, String) onChanged,
    required String placeholder,
    required bool multiline,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _D.sectionBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _D.sectionBg,
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _D.textPrimary,
                  ),
                ),
                _SmallOutlineButton(
                  icon: Icons.add_rounded,
                  label: addLabel,
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          // 항목들
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 12, right: 8),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: _D.inputBorder,
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          initialValue: entry.value,
                          decoration: _inputDeco(
                            '$placeholder ${i + 1}',
                            isTextarea: multiline,
                          ),
                          maxLines: multiline ? 3 : 1,
                          onChanged: (v) => onChanged(i, v),
                        ),
                      ),
                      if (items.length > 1)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => onRemove(i),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCaseCard(int index, _TestCaseData tc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _D.sectionBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _D.sectionBg,
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '테스트케이스 ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _D.textPrimary,
                  ),
                ),
                if (_testCases.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => setState(() => _testCases.removeAt(index)),
                  ),
              ],
            ),
          ),
          // 내용
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 입력값
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '입력값 (Inputs)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _D.label,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => tc.inputs.add('')),
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: _D.accentBlue,
                      ),
                      label: const Text(
                        '입력값 추가',
                        style: TextStyle(fontSize: 14, color: _D.accentBlue),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...tc.inputs.asMap().entries.map((entry) {
                  final i = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('tc_${index}_in_${i}_${entry.value}'),
                            initialValue: entry.value,
                            decoration: _inputDeco('입력값 ${i + 1}'),
                            onChanged: (v) => tc.inputs[i] = v,
                          ),
                        ),
                        if (tc.inputs.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                setState(() => tc.inputs.removeAt(i)),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // 출력값
                _buildLabeledField(
                  '출력 (Output)',
                  TextFormField(
                    key: ValueKey('tc_${index}_out_${tc.output}'),
                    initialValue: tc.output,
                    decoration: _inputDeco('출력 결과 (Output)'),
                    onChanged: (v) => tc.output = v,
                  ),
                ),
                const SizedBox(height: 16),
                // 공개 여부
                _buildLabeledField(
                  '공개 여부 (Visibility)',
                  DropdownButtonFormField<TestCaseVisibility>(
                    initialValue: tc.visibility,
                    decoration: _inputDeco(null),
                    items: const [
                      DropdownMenuItem(
                        value: TestCaseVisibility.public,
                        child: Text('PUBLIC — 공개'),
                      ),
                      DropdownMenuItem(
                        value: TestCaseVisibility.hidden,
                        child: Text('HIDDEN — 숨김'),
                      ),
                      DropdownMenuItem(
                        value: TestCaseVisibility.excluded,
                        child: Text('EXCLUDED — 제외'),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => tc.visibility = v ?? tc.visibility),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeTemplateCard(int index, _CodeTemplateData tmpl) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _D.sectionBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: _D.sectionBg,
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '템플릿 ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _D.textPrimary,
                  ),
                ),
                if (_codeTemplates.length > 1)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => setState(() {
                      tmpl.dispose();
                      _codeTemplates.removeAt(index);
                    }),
                  ),
              ],
            ),
          ),
          // 내용
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabeledField(
                  '언어 (Language)',
                  DropdownButtonFormField<String>(
                    initialValue: tmpl.language,
                    decoration: _inputDeco(null),
                    items: const [
                      DropdownMenuItem(value: 'KOTLIN', child: Text('KOTLIN')),
                      DropdownMenuItem(value: 'DART', child: Text('DART')),
                      DropdownMenuItem(value: 'PYTHON', child: Text('PYTHON')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => tmpl.updateLanguage(v));
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField('코드 템플릿', _buildCodeEditor(tmpl)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor(_CodeTemplateData tmpl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _dot(const Color(0xFFFF5F56)),
                const SizedBox(width: 6),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _dot(const Color(0xFF27C93F)),
                const SizedBox(width: 12),
                Text(
                  '${tmpl.language[0]}${tmpl.language.substring(1).toLowerCase()} Editor (Light)',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          CodeTheme(
            data: const CodeThemeData(styles: atomOneLightTheme),
            child: CodeField(
              controller: tmpl.codeController,
              textStyle: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.5,
                color: Color(0xFF0F172A),
              ),
              lineNumberStyle: const LineNumberStyle(
                width: 44,
                margin: 12,
                textStyle: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              maxLines: null,
              minLines: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggleBtn(String label, bool isActive, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive ? _D.accentBlue : _D.textLight,
            ),
          ),
        ),
      );

  Widget _buildJsonEditor() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _jsonError != null
              ? Colors.redAccent
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _dot(const Color(0xFFFF5F56)),
                const SizedBox(width: 6),
                _dot(const Color(0xFFFFBD2E)),
                const SizedBox(width: 6),
                _dot(const Color(0xFF27C93F)),
                const SizedBox(width: 12),
                const Text(
                  'JSON Editor (Light)',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CodeTheme(
            data: const CodeThemeData(styles: atomOneLightTheme),
            child: CodeField(
              controller: _jsonController,
              textStyle: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Color(0xFF0F172A),
              ),
              maxLines: null,
              minLines: 12,
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              onChanged: (v) {
                try {
                  jsonDecode(v);
                  if (_jsonError != null) setState(() => _jsonError = null);
                } catch (e) {
                  // ignore
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _syncToJson() {
    final list = _testCases
        .map(
          (tc) => {
            'inputValues': tc.inputs,
            'outputText': tc.output,
            'visibility': tc.visibility
                .toString()
                .split('.')
                .last
                .toUpperCase(),
          },
        )
        .toList();
    _jsonController.text = const JsonEncoder.withIndent('  ').convert(list);
  }

  bool _syncFromJson() {
    try {
      final raw = _jsonController.text.trim();
      if (raw.isEmpty) {
        setState(() {
          _testCases.clear();
          _testCases.add(_TestCaseData());
          _jsonError = null;
        });
        return true;
      }
      final decoded = jsonDecode(raw);
      final List<_TestCaseData> newCases = [];
      if (decoded is List) {
        for (var item in decoded) {
          if (item is Map) {
            newCases.add(_parseTestCaseMap(item));
          }
        }
      } else if (decoded is Map) {
        newCases.add(_parseTestCaseMap(decoded));
      }

      setState(() {
        _testCases.clear();
        _testCases.addAll(newCases.isEmpty ? [_TestCaseData()] : newCases);
        _jsonError = null;
      });
      return true;
    } catch (e) {
      setState(() => _jsonError = 'JSON 문법이 올바르지 않습니다: $e');
      return false;
    }
  }

  _TestCaseData _parseTestCaseMap(Map item) {
    final inputsRaw = item['inputValues'];
    final inputs = inputsRaw is List
        ? inputsRaw.map((e) => e.toString()).toList()
        : [''];
    final output = item['outputText']?.toString() ?? '';
    final visStr = (item['visibility']?.toString() ?? 'PUBLIC').toUpperCase();
    final visibility = TestCaseVisibility.values.firstWhere(
      (v) => v.toString().split('.').last.toUpperCase() == visStr,
      orElse: () => TestCaseVisibility.public,
    );
    return _TestCaseData(
      inputs: inputs,
      output: output,
      visibility: visibility,
    );
  }

  void _formatJson() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      _jsonController.text = const JsonEncoder.withIndent(
        '  ',
      ).convert(decoded);
      setState(() => _jsonError = null);
    } catch (e) {
      setState(() => _jsonError = '포맷팅 실패: JSON 문법을 확인해 주세요 ($e)');
    }
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── 과제 등록 ────────────────────────────────────────────────────────────────
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    if (_startAt.trim().isEmpty || _endAt.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작일시와 종료일시를 입력해주세요.')));
      return;
    }

    final reqList = _requirements
        .where((e) => e.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (e) => AssignmentRequirement(
            sortOrder: e.key + 1,
            requirementText: e.value.trim(),
          ),
        )
        .toList();

    final testCaseList = _testCases
        .asMap()
        .entries
        .where((e) => e.value.inputs.isNotEmpty || e.value.output.isNotEmpty)
        .map(
          (e) => AssignmentTestCase(
            seq: e.key + 1,
            inputValues: e.value.inputs.map((input) {
              return input.replaceAll('\\n', '\n');
            }).toList(),
            outputText: e.value.output.replaceAll('\\n', '\n'),
            visibility: e.value.visibility,
          ),
        )
        .toList();

    final codeTemplateList = _codeTemplates
        .where((e) => e.language.isNotEmpty)
        .map(
          (e) => CodeTemplate(
            language: e.language,
            functionTemplate: e.codeController.text.trim(),
          ),
        )
        .toList();

    ref
        .read(tasksManagementBlocProvider.notifier)
        .add(
          TasksManagementCreateAssignmentRequested(
            courseSlug: widget.course.slug,
            request: CreateAssignmentRequest(
              weekNo: _weekNo,
              orderInWeek: _orderInWeek,
              startAt: datetimeLocalKstToApiIso(_startAt),
              endAt: datetimeLocalKstToApiIso(_endAt),
              metadata: AssignmentMetadata(
                title: _title,
                description: _description,
                difficulty: _difficulty,
                learningGoals: _learningGoals
                    .where((e) => e.trim().isNotEmpty)
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (e) => LearningGoal(
                        sortOrder: e.key + 1,
                        learningGoalText: e.value.trim(),
                      ),
                    )
                    .toList(),
                requirements: reqList,
                testCases: testCaseList,
                codeTemplates: codeTemplateList,
                attributes: {},
              ),
            ),
          ),
        );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('과제 생성 요청을 보냈습니다.')));
    setState(() => _showAddForm = false);
  }
}

// ─── 과제 카드 ─────────────────────────────────────────────────────────────────
class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final String courseSlug;
  final WidgetRef ref;

  const _AssignmentCard({
    required this.assignment,
    required this.courseSlug,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(assignment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _D.sectionBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 + 상태 배지
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${assignment.weekNo}주차 — ${assignment.metadata.title}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _D.textPrimary,
                          letterSpacing: -0.31,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        assignment.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '난이도: ${assignment.metadata.difficulty}  |  기한: ${apiIsoToDisplayKst(assignment.startAt)} ~ ${apiIsoToDisplayKst(assignment.endAt)}',
                  style: const TextStyle(fontSize: 13, color: _D.textSub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              // 조회 버튼
              _CardTextButton(
                label: '조회',
                color: _D.accentBlue,
                onPressed: () => showAssignmentDetailsDialog(
                  context,
                  assignment,
                  courseSlug,
                ),
              ),
              const SizedBox(width: 4),
              // 수정 버튼 (TODO: 새 UI)
              _CardTextButton(
                label: '수정',
                color: _D.accentBlue,
                onPressed: () =>
                    showEditAssignmentDialog(context, assignment, courseSlug),
              ),
              const SizedBox(width: 4),
              // 삭제 버튼
              _CardTextButton(
                label: '삭제',
                color: Colors.red,
                onPressed: () => _showDeleteDialog(context),
              ),
            ],
          ),
        ],
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
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

// ─── 섹션 헤더 ─────────────────────────────────────────────────────────────────
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
            letterSpacing: -0.89,
          ),
        ),
      ],
    );
  }
}

// ─── 섹션 컨테이너 ─────────────────────────────────────────────────────────────
class _SectionContainer extends StatelessWidget {
  final Widget child;
  const _SectionContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFAF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: child,
    );
  }
}

// ─── 아웃라인 버튼 ─────────────────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: _D.accentBlue),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: _D.sectionBorder),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _SmallOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 12, color: _D.accentBlue),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: _D.sectionBorder),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─── 카드 텍스트 버튼 ─────────────────────────────────────────────────────────
class _CardTextButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _CardTextButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── 날짜+시간 피커 ───────────────────────────────────────────────────────────
class _DateTimePickerField extends StatefulWidget {
  final String initialValue;
  final String placeholder;
  final ValueChanged<String> onChanged;
  const _DateTimePickerField({
    required this.initialValue,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  State<_DateTimePickerField> createState() => _DateTimePickerFieldState();
}

class _DateTimePickerFieldState extends State<_DateTimePickerField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _DateTimePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _ctrl.text = widget.initialValue;
    }
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
        final current = tryParseDatetimeLocalKst(_ctrl.text) ?? DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime(2101),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(current),
        );
        if (time == null || !context.mounted) return;
        final dt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        final formatted = formatDatetimeLocalKst(dt);
        _ctrl.text = formatted;
        widget.onChanged(formatted);
      },
      decoration: _inputDeco(widget.placeholder).copyWith(
        prefixIcon: const Icon(
          Icons.calendar_month_outlined,
          size: 16,
          color: _D.accentBlue,
        ),
      ),
    );
  }
}

// ─── 헬퍼 데이터 클래스 ────────────────────────────────────────────────────────
class _TestCaseData {
  List<String> inputs;
  String output;
  TestCaseVisibility visibility;

  _TestCaseData({
    List<String>? inputs,
    String? output,
    TestCaseVisibility? visibility,
  }) : inputs = inputs ?? [''],
       output = output ?? '',
       visibility = visibility ?? TestCaseVisibility.public;
}

class _CodeTemplateData {
  String language;
  late final CodeController codeController;

  _CodeTemplateData({String language = 'KOTLIN', String? codeTemplate})
    : language = language {
    codeController = CodeController(
      text: (codeTemplate ?? _defaultCode(language)).replaceAll('\\n', '\n'),
      language: _getLanguage(language),
    );
  }

  void dispose() => codeController.dispose();

  void updateLanguage(String lang) {
    language = lang;
    codeController.language = _getLanguage(lang);
    codeController.text = _defaultCode(lang);
  }

  static String _defaultCode(String lang) {
    switch (lang.toUpperCase()) {
      case 'KOTLIN':
        return '/*\n[문제]\n> 이해한 방식으로 문제를 다시 정의해요\n[해석]\n> 문제의 요구사항을 분석해요\n[풀이]\n> 적용할 풀이를 작성해요\n*/\nfun solution(): String {\n    var answer = ""\n    return answer\n}';
      case 'DART':
        return '/*\n[문제]\n> 이해한 방식으로 문제를 다시 정의해요\n[해석]\n> 문제의 요구사항을 분석해요\n[풀이]\n> 적용할 풀이를 작성해요\n*/\n\nString solution() {\n  String answer = \'\';\n  return answer;\n}';
      case 'PYTHON':
        return "'''\n[문제]\n> 이해한 방식으로 문제를 다시 정의해요\n[해석]\n> 문제의 요구사항을 분석해요\n[풀이]\n> 적용할 풀이를 작성해요\n'''\n\ndef solution():\n    answer = ''\n    return answer";
      default:
        return '';
    }
  }

  dynamic _getLanguage(String lang) {
    switch (lang.toUpperCase()) {
      case 'KOTLIN':
        return kotlin;
      case 'DART':
        return dart;
      case 'PYTHON':
        return python;
      default:
        return kotlin;
    }
  }
}
