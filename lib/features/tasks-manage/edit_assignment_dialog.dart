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

import '../../core/utils/kst_datetime.dart';
import 'task_management.dart';

// ─── 디자인 토큰 (AssignmentsView와 동일하게 유지) ──────────────────────────────────
class _D {
  static const bg = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0F172B);
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

// ─── 진입 함수 ──────────────────────────────────────────────────────────────────
Future<void> showEditAssignmentDialog(
  BuildContext context,
  Assignment assignment,
  String courseSlug,
) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _EditAssignmentDialog(assignment: assignment, courseSlug: courseSlug),
  );
}

// ─── 다이얼로그 위젯 ─────────────────────────────────────────────────────────────
class _EditAssignmentDialog extends ConsumerStatefulWidget {
  final Assignment assignment;
  final String courseSlug;

  const _EditAssignmentDialog({
    required this.assignment,
    required this.courseSlug,
  });

  @override
  ConsumerState<_EditAssignmentDialog> createState() =>
      _EditAssignmentDialogState();
}

class _EditAssignmentDialogState extends ConsumerState<_EditAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();

  // 데이터
  late int _weekNo;
  late int _orderInWeek;
  late String _difficulty;
  late String _title;
  late String _description;
  late String _startAt;
  late String _endAt;
  late String _status;

  late List<String> _learningGoals;
  late List<String> _requirements;
  late List<_TestCaseData> _testCases;
  late List<_CodeTemplateData> _codeTemplates;

  // JSON Mode 관련
  bool _isJsonMode = false;
  late CodeController _jsonController;
  String? _jsonError;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _weekNo = a.weekNo;
    _orderInWeek = a.orderInWeek;
    _difficulty = a.metadata.difficulty;
    _title = a.metadata.title;
    _description = a.metadata.description ?? '';
    _startAt = apiIsoToDatetimeLocalKst(a.startAt);
    _endAt = apiIsoToDatetimeLocalKst(a.endAt);
    _status = a.status;

    _learningGoals = List<String>.from(
      a.metadata.learningGoals.map((e) => e.learningGoalText).toList(),
    );
    if (_learningGoals.isEmpty) _learningGoals.add('');

    _requirements = List<String>.from(
      a.metadata.requirements.map((e) => e.requirementText).toList(),
    );
    if (_requirements.isEmpty) _requirements.add('');

    _testCases = a.metadata.testCases
        .map(
          (e) => _TestCaseData(
            inputs: List<String>.from(e.inputValues.map((v) => v.toString())),
            output: e.outputText ?? '',
            visibility: e.visibility,
          ),
        )
        .toList();
    if (_testCases.isEmpty) _testCases.add(_TestCaseData());

    _codeTemplates = a.metadata.codeTemplates
        .map(
          (e) => _CodeTemplateData(
            language: e.language,
            codeTemplate: e.functionTemplate ?? e.codeTemplate,
          ),
        )
        .toList();
    if (_codeTemplates.isEmpty) _codeTemplates.add(_CodeTemplateData());

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
              title: '과제 수정',
              onClose: () => Navigator.of(context).pop(),
            ),
            // 콘텐츠
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 기본 정보
                      _SectionHeader(
                        icon: Icons.info_outline_rounded,
                        title: '기본 정보',
                      ),
                      const SizedBox(height: 12),
                      _SectionContainer(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildLabeledField(
                                    '주차',
                                    _buildWeekField(),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _buildLabeledField(
                                    '과제 순서 (Order)',
                                    _buildOrderField(),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 2,
                                  child: _buildLabeledField(
                                    '난이도',
                                    _buildDifficultyField(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildLabeledField(
                              '과제 제목',
                              TextFormField(
                                initialValue: _title,
                                decoration: _inputDeco('과제의 핵심 주제를 입력해주세요'),
                                onSaved: (v) => _title = v?.trim() ?? '',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? '필수 항목입니다'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildLabeledField(
                              '과제 설명',
                              TextFormField(
                                initialValue: _description,
                                decoration: _inputDeco(
                                  '과제에 대한 전반적인 설명을 작성해주세요',
                                  isTextarea: true,
                                ),
                                maxLines: 4,
                                onSaved: (v) => _description = v?.trim() ?? '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 2. 일정 설정
                      _SectionHeader(
                        icon: Icons.calendar_month_outlined,
                        title: '일정 설정',
                      ),
                      const SizedBox(height: 12),
                      _SectionContainer(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildLabeledField(
                                '시작 일시',
                                _DateTimePickerField(
                                  initialValue: _startAt,
                                  placeholder: '시작일시 선택',
                                  onChanged: (value) =>
                                      setState(() => _startAt = value),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildLabeledField(
                                '종료 일시',
                                _DateTimePickerField(
                                  initialValue: _endAt,
                                  placeholder: '종료일시 선택',
                                  onChanged: (value) =>
                                      setState(() => _endAt = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 3. 목표 및 요구사항
                      _SectionHeader(
                        icon: Icons.checklist_rounded,
                        title: '상세 목표 및 요구사항',
                      ),
                      const SizedBox(height: 12),
                      _buildDynamicCard(
                        title: '학습 목표',
                        addLabel: '추가하기',
                        items: _learningGoals,
                        onAdd: () => setState(() => _learningGoals.add('')),
                        onRemove: (i) =>
                            setState(() => _learningGoals.removeAt(i)),
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
                        onRemove: (i) =>
                            setState(() => _requirements.removeAt(i)),
                        onChanged: (i, v) => _requirements[i] = v,
                        placeholder: '요구사항',
                        multiline: true,
                      ),
                      const SizedBox(height: 28),

                      // 4. 테스트 예제
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionHeader(
                            icon: Icons.science_outlined,
                            title: '테스트 예제',
                          ),
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
                                  onPressed: () => setState(
                                    () => _testCases.add(_TestCaseData()),
                                  ),
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
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTestCaseCard(entry.key, entry.value),
                          );
                        }),
                      const SizedBox(height: 28),

                      // 5. 코드 템플릿
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionHeader(
                            icon: Icons.code_rounded,
                            title: '코드 템플릿',
                          ),
                          _OutlineButton(
                            icon: Icons.add_rounded,
                            label: '템플릿 추가',
                            onPressed: () => setState(
                              () => _codeTemplates.add(_CodeTemplateData()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._codeTemplates.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCodeTemplateCard(entry.key, entry.value),
                        );
                      }),

                      const SizedBox(height: 40),
                      // 저장 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _D.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '수정 내용 저장',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekField() => TextFormField(
    initialValue: _weekNo.toString(),
    decoration: _inputDeco('예: 1'),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSaved: (v) => _weekNo = int.tryParse(v ?? '1') ?? 1,
    validator: (v) => (v == null || v.trim().isEmpty) ? '필수' : null,
  );

  Widget _buildOrderField() => TextFormField(
    initialValue: _orderInWeek.toString(),
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
        ),
      ),
      const SizedBox(height: 6),
      field,
    ],
  );

  // Dynamic Card (학습 목표, 요구사항)
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

  // TestCase Card
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
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    _SmallOutlineButton(
                      icon: Icons.add,
                      label: '입력값 추가',
                      onPressed: () => setState(() => tc.inputs.add('')),
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
                            key: ValueKey(
                              'etc_${index}_in_${i}_${entry.value}',
                            ),
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
                _buildLabeledField(
                  '출력 (Output)',
                  TextFormField(
                    key: ValueKey('etc_${index}_out_${tc.output}'),
                    initialValue: tc.output,
                    decoration: _inputDeco('출력값을 입력하세요', isTextarea: true),
                    maxLines: 3,
                    onChanged: (v) => tc.output = v,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  '공개 여부',
                  DropdownButtonFormField<TestCaseVisibility>(
                    initialValue: tc.visibility,
                    decoration: _inputDeco(null),
                    items: const [
                      DropdownMenuItem(
                        value: TestCaseVisibility.public,
                        child: Text('PUBLIC'),
                      ),
                      DropdownMenuItem(
                        value: TestCaseVisibility.hidden,
                        child: Text('HIDDEN'),
                      ),
                      DropdownMenuItem(
                        value: TestCaseVisibility.excluded,
                        child: Text('EXCLUDED'),
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

  // CodeTemplate Card
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
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabeledField(
                  '언어',
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
        color: _D.sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: _D.sectionBorder)),
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
                  tmpl.language,
                  style: const TextStyle(
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
            data: CodeThemeData(styles: atomOneLightTheme),
            child: CodeField(
              controller: tmpl.codeController,
              textStyle: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: _D.textPrimary,
              ),
              maxLines: null,
              minLines: 8,
              decoration: const BoxDecoration(color: _D.sectionBg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  void _submit() {
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

    if (_startAt.trim().isEmpty || _endAt.trim().isEmpty) return;

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
          TasksManagementUpdateAssignmentRequested(
            courseSlug: widget.courseSlug,
            assignmentId: widget.assignment.id,
            request: UpdateAssignmentRequest(
              orderInWeek: _orderInWeek,
              status: _status,
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
              ),
            ),
          ),
        );

    Navigator.of(context).pop();
  }

  // ── JSON 동기화 & UI ──────────────────────────────────────────────────────────

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
                // 실시간 문법 체크
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
          _testCases = [_TestCaseData()];
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
        _testCases = newCases.isEmpty ? [_TestCaseData()] : newCases;
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
}

// ─── 공통 위젯들 ─────────────────────────────────────────────────────────────
class _DialogHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  const _DialogHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
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
            letterSpacing: -0.89,
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
        foregroundColor: _D.accentBlue,
        side: const BorderSide(color: _D.sectionBorder),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
        foregroundColor: _D.accentBlue,
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

// ─── 데이터 클래스 (AssignmentsView와 동일) ───────────────────────────────────────────
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
  _CodeTemplateData({this.language = 'KOTLIN', String? codeTemplate}) {
    codeController = CodeController(
      text: (codeTemplate ?? _defaultCode('KOTLIN')).replaceAll('\\n', '\n'),
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
        return 'fun solution(): String {\n    var answer = ""\n    return answer\n}';
      case 'DART':
        return 'String solution() {\n  String answer = \'\';\n  return answer;\n}';
      case 'PYTHON':
        return "def solution():\n    answer = ''\n    return answer";
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
