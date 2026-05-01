import 'dart:convert';

import 'package:aandi_course_api/aandi_course_api.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight/languages/dart.dart' as highlight_dart;
import 'package:highlight/languages/json.dart' as highlight_json;
import 'package:highlight/languages/kotlin.dart' as highlight_kotlin;
import 'package:highlight/languages/python.dart' as highlight_python;

import '../../core/utils/kst_datetime.dart';
import 'task_management.dart';

class _D {
  static const bg = Color(0xFFFCFCFC);
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _D.sectionBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _D.accentBlue, width: 1.5),
      ),
    );

enum AssignmentFormMode { create, edit }

class AssignmentFormPage extends ConsumerStatefulWidget {
  const AssignmentFormPage.create({super.key, required this.courseSlug})
    : mode = AssignmentFormMode.create,
      assignmentId = null;

  const AssignmentFormPage.edit({
    super.key,
    required this.courseSlug,
    required String this.assignmentId,
  }) : mode = AssignmentFormMode.edit;

  final AssignmentFormMode mode;
  final String courseSlug;
  final String? assignmentId;

  @override
  ConsumerState<AssignmentFormPage> createState() => _AssignmentFormPageState();
}

class _AssignmentFormPageState extends ConsumerState<AssignmentFormPage> {
  bool _detailsRequested = false;
  bool _submissionInFlight = false;

  bool get _isEdit => widget.mode == AssignmentFormMode.edit;

  @override
  void initState() {
    super.initState();
    _requestDetailsIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AssignmentFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseSlug != widget.courseSlug ||
        oldWidget.assignmentId != widget.assignmentId ||
        oldWidget.mode != widget.mode) {
      _detailsRequested = false;
      _submissionInFlight = false;
      _requestDetailsIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tasksManagementBlocProvider, (prev, next) {
      if (!_submissionInFlight) return;
      if (prev?.isCreating == true && next.isCreating == false) {
        if (next.errorMessage == null) {
          _submissionInFlight = false;
          context.go(
            '/dashboard/courses/${Uri.encodeComponent(widget.courseSlug)}',
          );
        } else {
          _submissionInFlight = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 실패: ${next.errorMessage}')),
          );
        }
      }
    });

    final state = ref.watch(tasksManagementBlocProvider);
    final assignment = _isEdit ? _selectedAssignment(state) : null;

    if (_isEdit && assignment == null) {
      return _buildDetailsLoading(state);
    }

    return _AssignmentForm(
      key: ValueKey('${widget.mode.name}-${widget.assignmentId ?? 'new'}'),
      mode: widget.mode,
      courseSlug: widget.courseSlug,
      initialAssignment: assignment,
      isSubmitting: state.isCreating,
      onCancel: () => context.go(
        '/dashboard/courses/${Uri.encodeComponent(widget.courseSlug)}',
      ),
      onCreate: (request) {
        _submissionInFlight = true;
        ref
            .read(tasksManagementBlocProvider.notifier)
            .add(
              TasksManagementCreateAssignmentRequested(
                courseSlug: widget.courseSlug,
                request: request,
              ),
            );
      },
      onUpdate: (request) {
        final assignmentId = widget.assignmentId;
        if (assignmentId == null) return;
        _submissionInFlight = true;
        ref
            .read(tasksManagementBlocProvider.notifier)
            .add(
              TasksManagementUpdateAssignmentRequested(
                courseSlug: widget.courseSlug,
                assignmentId: assignmentId,
                request: request,
              ),
            );
      },
    );
  }

  void _requestDetailsIfNeeded() {
    if (!_isEdit || _detailsRequested) return;
    final assignmentId = widget.assignmentId;
    if (assignmentId == null || assignmentId.isEmpty) return;

    _detailsRequested = true;
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(tasksManagementBlocProvider.notifier)
          .add(
            TasksManagementAssignmentDetailsRequested(
              courseSlug: widget.courseSlug,
              assignmentId: assignmentId,
            ),
          );
    });
  }

  Assignment? _selectedAssignment(TasksManagementState state) {
    final selected = state.selectedAssignment;
    if (selected?.id == widget.assignmentId) {
      return selected;
    }
    return null;
  }

  Widget _buildDetailsLoading(TasksManagementState state) {
    if (state.status == TasksManagementStatus.failure &&
        state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _D.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => context.go(
                  '/dashboard/courses/${Uri.encodeComponent(widget.courseSlug)}',
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('코스 상세로 돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    _requestDetailsIfNeeded();
    return const Center(child: CircularProgressIndicator());
  }
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({
    super.key,
    required this.mode,
    required this.courseSlug,
    required this.initialAssignment,
    required this.isSubmitting,
    required this.onCancel,
    required this.onCreate,
    required this.onUpdate,
  });

  final AssignmentFormMode mode;
  final String courseSlug;
  final Assignment? initialAssignment;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final ValueChanged<CreateAssignmentRequest> onCreate;
  final ValueChanged<UpdateAssignmentRequest> onUpdate;

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final _formKey = GlobalKey<FormState>();

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

  bool _isJsonMode = false;
  late CodeController _jsonController;
  String? _jsonError;

  bool get _isEdit => widget.mode == AssignmentFormMode.edit;

  @override
  void initState() {
    super.initState();
    _applyInitialValues(widget.initialAssignment);
    _jsonController = CodeController(text: '', language: highlight_json.json);
  }

  @override
  void dispose() {
    for (final template in _codeTemplates) {
      template.dispose();
    }
    _jsonController.dispose();
    super.dispose();
  }

  void _applyInitialValues(Assignment? assignment) {
    _weekNo = assignment?.weekNo ?? 1;
    _orderInWeek = assignment?.orderInWeek ?? 1;
    _difficulty = assignment?.metadata.difficulty ?? 'LOW';
    _title = assignment?.metadata.title ?? '';
    _description = assignment?.metadata.description ?? '';
    _startAt = assignment == null
        ? ''
        : apiIsoToDatetimeLocalKst(assignment.startAt);
    _endAt = assignment == null
        ? ''
        : apiIsoToDatetimeLocalKst(assignment.endAt);
    _status = assignment?.status ?? 'DRAFT';

    _learningGoals =
        assignment?.metadata.learningGoals
            .map((goal) => goal.learningGoalText)
            .toList() ??
        [''];
    if (_learningGoals.isEmpty) _learningGoals.add('');

    _requirements =
        assignment?.metadata.requirements
            .map((requirement) => requirement.requirementText)
            .toList() ??
        [''];
    if (_requirements.isEmpty) _requirements.add('');

    _testCases =
        assignment?.metadata.testCases
            .map(
              (testCase) => _TestCaseData(
                inputs: testCase.inputValues
                    .map((value) => value.toString())
                    .toList(),
                output: testCase.outputText ?? '',
                visibility: testCase.visibility,
              ),
            )
            .toList() ??
        [_TestCaseData()];
    if (_testCases.isEmpty) _testCases.add(_TestCaseData());

    _codeTemplates =
        assignment?.metadata.codeTemplates
            .map(
              (template) => _CodeTemplateData(
                language: template.language,
                codeTemplate:
                    template.functionTemplate ?? template.codeTemplate ?? '',
              ),
            )
            .toList() ??
        [_CodeTemplateData()];
    if (_codeTemplates.isEmpty) _codeTemplates.add(_CodeTemplateData());
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? '과제 수정' : '새 과제 추가';
    final subtitle = _isEdit
        ? '$_weekNo주차 과제 정보를 수정합니다.'
        : '${widget.courseSlug} 코스에 새 과제를 등록합니다.';

    return Container(
      color: _D.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(title, subtitle),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    icon: Icons.info_outline_rounded,
                    title: '기본 정보',
                  ),
                  const SizedBox(height: 12),
                  _SectionContainer(
                    child: Column(
                      children: [
                        _FieldGrid(
                          flexes: const [1, 1, 2],
                          children: [
                            _buildLabeledField('주차', _buildWeekField()),
                            _buildLabeledField(
                              '순서 (Order)',
                              _buildOrderField(),
                            ),
                            _buildLabeledField('난이도', _buildDifficultyField()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildLabeledField(
                          '과제 제목',
                          TextFormField(
                            initialValue: _title,
                            decoration: _inputDeco('과제의 핵심 주제를 입력해주세요'),
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: null,
                            onSaved: (value) => _title = value?.trim() ?? '',
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
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
                            keyboardType: TextInputType.multiline,
                            minLines: 5,
                            maxLines: null,
                            onSaved: (value) =>
                                _description = value?.trim() ?? '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _SectionHeader(
                    icon: Icons.calendar_month_outlined,
                    title: '일정 설정',
                  ),
                  const SizedBox(height: 12),
                  _SectionContainer(
                    child: _FieldGrid(
                      children: [
                        _buildLabeledField(
                          '시작 일시',
                          _DateTimePickerField(
                            initialValue: _startAt,
                            placeholder: '시작일시 선택',
                            onChanged: (value) =>
                                setState(() => _startAt = value),
                          ),
                        ),
                        _buildLabeledField(
                          '종료 일시',
                          _DateTimePickerField(
                            initialValue: _endAt,
                            placeholder: '종료일시 선택',
                            onChanged: (value) =>
                                setState(() => _endAt = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
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
                    onRemove: (index) =>
                        setState(() => _learningGoals.removeAt(index)),
                    onChanged: (index, value) => _learningGoals[index] = value,
                    placeholder: '학습 목표',
                    multiline: false,
                  ),
                  const SizedBox(height: 12),
                  _buildDynamicCard(
                    title: '요구사항 (Requirements)',
                    addLabel: '추가하기',
                    items: _requirements,
                    onAdd: () => setState(() => _requirements.add('')),
                    onRemove: (index) =>
                        setState(() => _requirements.removeAt(index)),
                    onChanged: (index, value) => _requirements[index] = value,
                    placeholder: '요구사항',
                    multiline: true,
                  ),
                  const SizedBox(height: 28),
                  _buildTestCaseHeader(),
                  const SizedBox(height: 12),
                  if (_isJsonMode)
                    _buildJsonMode()
                  else
                    ..._testCases.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTestCaseCard(entry.key, entry.value),
                      ),
                    ),
                  const SizedBox(height: 28),
                  _buildCodeTemplateHeader(),
                  const SizedBox(height: 12),
                  ..._codeTemplates.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCodeTemplateCard(entry.key, entry.value),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _D.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _D.textSub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: widget.isSubmitting ? null : widget.onCancel,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('돌아가기'),
        ),
      ],
    );
  }

  Widget _buildWeekField() => TextFormField(
    initialValue: _weekNo.toString(),
    enabled: !_isEdit,
    decoration: _inputDeco(_isEdit ? '수정할 수 없습니다' : '예: 1'),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSaved: (value) => _weekNo = int.tryParse(value ?? '1') ?? 1,
    validator: (value) => (value == null || value.trim().isEmpty) ? '필수' : null,
  );

  Widget _buildOrderField() => TextFormField(
    initialValue: _orderInWeek.toString(),
    decoration: _inputDeco('예: 1'),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSaved: (value) => _orderInWeek = int.tryParse(value ?? '1') ?? 1,
    validator: (value) => (value == null || value.trim().isEmpty) ? '필수' : null,
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
    onChanged: (value) => setState(() => _difficulty = value ?? _difficulty),
    onSaved: (value) => _difficulty = value ?? _difficulty,
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

  Widget _buildDynamicCard({
    required String title,
    required String addLabel,
    required List<String> items,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
    required void Function(int index, String value) onChanged,
    required String placeholder,
    required bool multiline,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        children: [
          _CardHeader(
            title: title,
            trailing: _SmallOutlineButton(
              icon: Icons.add_rounded,
              label: addLabel,
              onPressed: onAdd,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final index = entry.key;
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
                            '$placeholder ${index + 1}',
                            isTextarea: multiline,
                          ),
                          keyboardType: TextInputType.multiline,
                          minLines: multiline ? 3 : 1,
                          maxLines: null,
                          onChanged: (value) => onChanged(index, value),
                        ),
                      ),
                      if (items.length > 1)
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          onPressed: () => onRemove(index),
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

  Widget _buildTestCaseHeader() {
    return Row(
      children: [
        const _SectionHeader(icon: Icons.science_outlined, title: '테스트 예제'),
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
                if (_isJsonMode && _syncFromJson()) {
                  setState(() => _isJsonMode = false);
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
        if (_isJsonMode)
          _SmallOutlineButton(
            icon: Icons.format_align_left_rounded,
            label: 'JSON 포맷팅',
            onPressed: _formatJson,
          )
        else
          _SmallOutlineButton(
            icon: Icons.add_rounded,
            label: '테스트케이스 추가',
            onPressed: () => setState(() => _testCases.add(_TestCaseData())),
          ),
      ],
    );
  }

  Widget _buildJsonMode() {
    return Column(
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
    );
  }

  Widget _buildTestCaseCard(int index, _TestCaseData testCase) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        children: [
          _CardHeader(
            title: '테스트케이스 ${index + 1}',
            trailing: _testCases.length > 1
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => setState(() => _testCases.removeAt(index)),
                  )
                : null,
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
                      icon: Icons.add_rounded,
                      label: '입력값 추가',
                      onPressed: () => setState(() => testCase.inputs.add('')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...testCase.inputs.asMap().entries.map((entry) {
                  final inputIndex = entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'tc_${index}_in_${inputIndex}_${entry.value}',
                            ),
                            initialValue: entry.value,
                            decoration: _inputDeco('입력값 ${inputIndex + 1}'),
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: null,
                            onChanged: (value) =>
                                testCase.inputs[inputIndex] = value,
                          ),
                        ),
                        if (testCase.inputs.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () => setState(
                              () => testCase.inputs.removeAt(inputIndex),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                _buildLabeledField(
                  '출력 (Output)',
                  TextFormField(
                    key: ValueKey('tc_${index}_out_${testCase.output}'),
                    initialValue: testCase.output,
                    decoration: _inputDeco('출력값을 입력하세요', isTextarea: true),
                    keyboardType: TextInputType.multiline,
                    minLines: 3,
                    maxLines: null,
                    onChanged: (value) => testCase.output = value,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField(
                  '공개 여부',
                  DropdownButtonFormField<TestCaseVisibility>(
                    initialValue: testCase.visibility,
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
                    onChanged: (value) => setState(
                      () => testCase.visibility = value ?? testCase.visibility,
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

  Widget _buildCodeTemplateHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const _SectionHeader(icon: Icons.code_rounded, title: '코드 템플릿'),
        _SmallOutlineButton(
          icon: Icons.add_rounded,
          label: '템플릿 추가',
          onPressed: () =>
              setState(() => _codeTemplates.add(_CodeTemplateData())),
        ),
      ],
    );
  }

  Widget _buildCodeTemplateCard(int index, _CodeTemplateData template) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: Column(
        children: [
          _CardHeader(
            title: '템플릿 ${index + 1}',
            trailing: _codeTemplates.length > 1
                ? IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () => setState(() {
                      template.dispose();
                      _codeTemplates.removeAt(index);
                    }),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabeledField(
                  '언어',
                  DropdownButtonFormField<String>(
                    initialValue: template.language,
                    decoration: _inputDeco(null),
                    items: const [
                      DropdownMenuItem(value: 'KOTLIN', child: Text('KOTLIN')),
                      DropdownMenuItem(value: 'DART', child: Text('DART')),
                      DropdownMenuItem(value: 'PYTHON', child: Text('PYTHON')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => template.updateLanguage(value));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _buildLabeledField('코드 템플릿', _buildCodeEditor(template)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditor(_CodeTemplateData template) {
    return Container(
      decoration: BoxDecoration(
        color: _D.sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _EditorHeader(label: '${template.language} Editor'),
          CodeTheme(
            data: const CodeThemeData(styles: atomOneLightTheme),
            child: CodeField(
              controller: template.codeController,
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
        color: _D.sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _jsonError != null ? Colors.redAccent : _D.sectionBorder,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _EditorHeader(label: 'JSON Editor'),
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
              decoration: const BoxDecoration(color: _D.sectionBg),
              onChanged: (value) {
                try {
                  jsonDecode(value);
                  if (_jsonError != null) {
                    setState(() => _jsonError = null);
                  }
                } catch (_) {
                  // The explicit mode switch/save path reports the parse error.
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        OutlinedButton(
          onPressed: widget.isSubmitting ? null : widget.onCancel,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('취소'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: widget.isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _D.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: widget.isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(_isEdit ? Icons.save_outlined : Icons.add_rounded),
          label: Text(_isEdit ? '수정 내용 저장' : '과제 등록'),
        ),
      ],
    );
  }

  void _submit() {
    if (_isJsonMode && !_syncFromJson()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON 문법 오류를 먼저 해결해 주세요.')));
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();

    if (_startAt.trim().isEmpty || _endAt.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('시작일시와 종료일시를 입력해주세요.')));
      return;
    }

    final metadata = _buildMetadata();
    if (_isEdit) {
      widget.onUpdate(
        UpdateAssignmentRequest(
          orderInWeek: _orderInWeek,
          status: _status,
          startAt: datetimeLocalKstToApiIso(_startAt),
          endAt: datetimeLocalKstToApiIso(_endAt),
          metadata: metadata,
        ),
      );
      return;
    }

    widget.onCreate(
      CreateAssignmentRequest(
        weekNo: _weekNo,
        orderInWeek: _orderInWeek,
        startAt: datetimeLocalKstToApiIso(_startAt),
        endAt: datetimeLocalKstToApiIso(_endAt),
        metadata: metadata,
      ),
    );
  }

  AssignmentMetadata _buildMetadata() {
    final learningGoals = _learningGoals
        .where((goal) => goal.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => LearningGoal(
            sortOrder: entry.key + 1,
            learningGoalText: entry.value.trim(),
          ),
        )
        .toList();

    final requirements = _requirements
        .where((requirement) => requirement.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => AssignmentRequirement(
            sortOrder: entry.key + 1,
            requirementText: entry.value.trim(),
          ),
        )
        .toList();

    final testCases = _testCases
        .asMap()
        .entries
        .where(
          (entry) =>
              entry.value.inputs.isNotEmpty || entry.value.output.isNotEmpty,
        )
        .map(
          (entry) => AssignmentTestCase(
            seq: entry.key + 1,
            inputValues: entry.value.inputs
                .map((input) => input.replaceAll('\\n', '\n'))
                .toList(),
            outputText: entry.value.output.replaceAll('\\n', '\n'),
            visibility: entry.value.visibility,
          ),
        )
        .toList();

    final codeTemplates = _codeTemplates
        .where((template) => template.language.isNotEmpty)
        .map(
          (template) => CodeTemplate(
            language: template.language,
            functionTemplate: template.codeController.text.trim(),
          ),
        )
        .toList();

    return AssignmentMetadata(
      title: _title,
      description: _description,
      difficulty: _difficulty,
      learningGoals: learningGoals,
      requirements: requirements,
      testCases: testCases,
      codeTemplates: codeTemplates,
      attributes: {},
    );
  }

  void _syncToJson() {
    final list = _testCases
        .map(
          (testCase) => {
            'inputValues': testCase.inputs,
            'outputText': testCase.output,
            'visibility': testCase.visibility.name.toUpperCase(),
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
      final newCases = <_TestCaseData>[];
      if (decoded is List) {
        for (final item in decoded) {
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
    } catch (error) {
      setState(() => _jsonError = 'JSON 문법이 올바르지 않습니다: $error');
      return false;
    }
  }

  _TestCaseData _parseTestCaseMap(Map<dynamic, dynamic> item) {
    final inputsRaw = item['inputValues'];
    final inputs = inputsRaw is List
        ? inputsRaw.map((value) => value.toString()).toList()
        : [''];
    final output = item['outputText']?.toString() ?? '';
    final visibilityText = (item['visibility']?.toString() ?? 'PUBLIC')
        .toUpperCase();
    final visibility = TestCaseVisibility.values.firstWhere(
      (value) => value.name.toUpperCase() == visibilityText,
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
    } catch (error) {
      setState(() => _jsonError = '포맷팅 실패: JSON 문법을 확인해 주세요 ($error)');
    }
  }
}

class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.children, this.flexes});

  final List<Widget> children;
  final List<int>? flexes;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: children.asMap().entries.expand((entry) {
            final index = entry.key;
            final flex = flexes != null && index < flexes!.length
                ? flexes![index]
                : 1;
            return [
              Expanded(flex: flex, child: entry.value),
              if (index != children.length - 1) const SizedBox(width: 20),
            ];
          }).toList(),
        );
      },
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _D.sectionBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.sectionBorder),
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _D.sectionBg,
        border: Border(bottom: BorderSide(color: _D.sectionBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
          ?trailing,
        ],
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SmallOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _D.accentBlue,
        side: const BorderSide(color: _D.sectionBorder),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
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
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _DateTimePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? '필수 항목입니다' : null,
      onTap: () async {
        final current =
            tryParseDatetimeLocalKst(_controller.text) ?? DateTime.now();
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
        final dateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        final formatted = formatDatetimeLocalKst(dateTime);
        _controller.text = formatted;
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
       visibility = visibility ?? TestCaseVisibility.public {
    if (this.inputs.isEmpty) {
      this.inputs = [''];
    }
  }
}

class _CodeTemplateData {
  String language;
  late final CodeController codeController;

  _CodeTemplateData({String language = 'KOTLIN', String? codeTemplate})
    : language = language.toUpperCase() {
    codeController = CodeController(
      text:
          (codeTemplate?.isNotEmpty == true
                  ? codeTemplate!
                  : _defaultCode(this.language))
              .replaceAll('\\n', '\n'),
      language: _getLanguage(this.language),
    );
  }

  void dispose() => codeController.dispose();

  void updateLanguage(String value) {
    language = value.toUpperCase();
    codeController.language = _getLanguage(language);
    codeController.text = _defaultCode(language);
  }

  static dynamic _getLanguage(String language) {
    switch (language.toUpperCase()) {
      case 'DART':
        return highlight_dart.dart;
      case 'PYTHON':
        return highlight_python.python;
      case 'KOTLIN':
      default:
        return highlight_kotlin.kotlin;
    }
  }

  static String _defaultCode(String language) {
    switch (language.toUpperCase()) {
      case 'DART':
        return '/*\n[문제]\n> 이해한 방식으로 문제를 다시 정의해요\n[해석]\n> 문제의 요구사항을 분석해요\n[풀이]\n> 적용할 풀이를 작성해요\n*/\n\nString solution() {\n  String answer = "";\n  return answer;\n}';
      case 'PYTHON':
        return "'''\n[문제]\n> 이해한 방식으로 문제를 다시 정의해요\n[해석]\n> 문제의 요구사항을 분석해요\n[풀이]\n> 적용할 풀이를 작성해요\n'''\n\ndef solution():\n    answer = ''\n    return answer";
      case 'KOTLIN':
      default:
        return '/*\n[문제]\n> 이해한 방식으로 문제를 다시 정의해요\n[해석]\n> 문제의 요구사항을 분석해요\n[풀이]\n> 적용할 풀이를 작성해요\n*/\nfun solution(): String {\n    var answer = ""\n    return answer\n}';
    }
  }
}
