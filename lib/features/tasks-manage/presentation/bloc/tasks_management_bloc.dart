import 'dart:async';

import 'package:aandi_course_api/aandi_course_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/api_error_feedback.dart';
import '../providers/tasks_management_providers.dart';
import 'tasks_management_event.dart';
import 'tasks_management_state.dart';
import '../../../users-manage/presentation/bloc/users_management_bloc.dart';

part 'tasks_management_bloc.g.dart';

@riverpod
class TasksManagementBloc extends _$TasksManagementBloc {
  final Map<Type, Future<void> Function(dynamic)> _handlers = {};

  void on<T extends TasksManagementEvent>(
    Future<void> Function(T event) handler,
  ) {
    _handlers[T] = (event) => handler(event as T);
  }

  void add(TasksManagementEvent event) {
    final handler = _handlers[event.runtimeType];
    if (handler != null) {
      handler(event);
    }
  }

  @override
  TasksManagementState build() {
    on<TasksManagementStarted>((event) async => _loadCourses());
    on<TasksManagementRefreshRequested>((event) async => _loadCourses());
    on<TasksManagementCourseSelected>(
      (event) async => _selectCourse(event.course),
    );
    on<TasksManagementEnrollmentsRequested>(
      (event) async => _loadEnrollments(event.courseSlug),
    );

    on<TasksManagementCreateCourseRequested>((event) async {
      await _createCourse(
        slug: event.slug,
        title: event.title,
        description: event.description,
        phase: event.phase,
        targetTrack: event.targetTrack,
        startDate: event.startDate,
        endDate: event.endDate,
      );
    });

    on<TasksManagementAssignmentsRequested>((event) async {
      await _loadAssignments(
        event.courseSlug,
        weekNo: event.weekNo,
        status: event.status,
      );
    });

    on<TasksManagementCreateAssignmentRequested>((event) async {
      await _createAssignment(
        courseSlug: event.courseSlug,
        request: event.request,
      );
    });

    on<TasksManagementAssignmentDetailsRequested>((event) async {
      await _loadAssignmentDetails(
        courseSlug: event.courseSlug,
        assignmentId: event.assignmentId,
      );
    });

    on<TasksManagementAssignmentSubmissionStatusesRequested>((event) async {
      await _loadAssignmentSubmissionStatuses(
        courseSlug: event.courseSlug,
        assignmentId: event.assignmentId,
      );
    });

    on<TasksManagementAddEnrollmentRequested>((event) async {
      await _addEnrollment(
        courseSlug: event.courseSlug,
        request: event.request,
      );
    });

    on<TasksManagementUpdateEnrollmentStatusRequested>((event) async {
      await _updateEnrollmentStatus(
        courseSlug: event.courseSlug,
        userId: event.userId,
        request: event.request,
      );
    });

    on<TasksManagementUpdateAssignmentRequested>((event) async {
      await _updateAssignment(
        courseSlug: event.courseSlug,
        assignmentId: event.assignmentId,
        request: event.request,
      );
    });

    on<TasksManagementAssignmentDeletedRequested>((event) async {
      await _deleteAssignment(
        courseSlug: event.courseSlug,
        assignmentId: event.assignmentId,
      );
    });

    on<TasksManagementCourseDeletedRequested>((event) async {
      await _deleteCourse(courseSlug: event.courseSlug);
    });

    on<TasksManagementUpdateCourseRequested>((event) async {
      await _updateCourse(courseSlug: event.courseSlug, request: event.request);
    });

    on<TasksManagementDeleteEnrollmentRequested>((event) async {
      await _deleteEnrollment(
        courseSlug: event.courseSlug,
        userId: event.userId,
      );
    });

    on<TasksManagementUserSearchRequested>((event) async {
      await _searchUser(query: event.query);
    });

    on<TasksManagementClearUserSearch>((event) async {
      state = state.copyWith(clearSearchedUser: true, userNotFound: false);
    });

    Future.microtask(() => add(const TasksManagementStarted()));
    return const TasksManagementState.initial();
  }

  Future<void> _loadCourses() async {
    state = state.copyWith(
      status: TasksManagementStatus.loading,
      clearError: true,
    );
    try {
      final useCase = ref.read(getCoursesUseCaseProvider);
      final courses = await useCase();
      state = state.copyWith(
        status: TasksManagementStatus.success,
        courses: courses,
      );
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _createCourse({
    required String slug,
    required String title,
    String? description,
    required String phase,
    required String targetTrack,
    required String startDate,
    required String endDate,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final useCase = ref.read(createCourseUseCaseProvider);
      await useCase(
        slug: slug,
        title: title,
        description: description,
        phase: phase,
        targetTrack: targetTrack,
        startDate: startDate,
        endDate: endDate,
      );

      await _loadCourses();
      state = state.copyWith(isCreating: false);
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isCreating: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _selectCourse(CourseSummary course) async {
    state = state.copyWith(
      selectedCourse: course,
      selectedCourseEnrollments: null,
      selectedCourseAssignments: null,
      clearAssignmentSubmissionStatuses: true,
      clearError: true,
    );
    add(TasksManagementEnrollmentsRequested(course.slug));
    add(TasksManagementAssignmentsRequested(courseSlug: course.slug));
  }

  Future<void> _loadEnrollments(String courseSlug) async {
    state = state.copyWith(isLoadingDetails: true, clearError: true);
    try {
      final enrollments = await ref.read(getEnrollmentsUseCaseProvider)(
        courseSlug: courseSlug,
      );
      // Ensure the course hasn't changed while loading
      if (state.selectedCourse?.slug == courseSlug) {
        state = state.copyWith(
          selectedCourseEnrollments: enrollments,
          isLoadingDetails: false,
        );
      }
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      // Only record the error — don't flip the whole page to failure state.
      state = state.copyWith(
        isLoadingDetails: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _addEnrollment({
    required String courseSlug,
    required AddEnrollmentRequest request,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      await ref.read(addEnrollmentUseCaseProvider)(
        courseSlug: courseSlug,
        request: request,
      );
      state = state.copyWith(isCreating: false);
      add(TasksManagementEnrollmentsRequested(courseSlug));
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      String errorMessage = '수강생 등록 중 오류가 발생했습니다: $e';
      if (e is CourseApiException) {
        errorMessage =
            '수강생 등록 실패: ${e.message} (statusCode: ${e.statusCode}, code: ${e.code})';
      }
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isCreating: false,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> _updateEnrollmentStatus({
    required String courseSlug,
    required String userId,
    required UpdateEnrollmentStatusRequest request,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      await ref.read(updateEnrollmentStatusUseCaseProvider)(
        courseSlug: courseSlug,
        userId: userId,
        request: request,
      );
      state = state.copyWith(isCreating: false);
      add(TasksManagementEnrollmentsRequested(courseSlug));
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      String errorMessage = '수강생 상태 변경 중 오류가 발생했습니다: $e';
      if (e is CourseApiException) {
        errorMessage =
            '수강생 상태 변경 실패: ${e.message} (statusCode: ${e.statusCode}, code: ${e.code})';
      }
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isCreating: false,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> _loadAssignments(
    String courseSlug, {
    int? weekNo,
    String? status,
  }) async {
    state = state.copyWith(isLoadingDetails: true, clearError: true);
    try {
      final assignments = await ref.read(getAssignmentsUseCaseProvider)(
        courseSlug: courseSlug,
        weekNo: weekNo,
        status: status,
      );
      state = state.copyWith(
        selectedCourseAssignments: assignments,
        isLoadingDetails: false,
      );
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(
        isLoadingDetails: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _loadAssignmentDetails({
    required String courseSlug,
    required String assignmentId,
  }) async {
    state = state.copyWith(
      isLoadingDetails: true,
      selectedAssignment: null,
      clearError: true,
    );
    try {
      final assignment = await ref.read(getAssignmentDetailsUseCaseProvider)(
        courseSlug: courseSlug,
        assignmentId: assignmentId,
      );

      state = state.copyWith(
        selectedAssignment: assignment,
        isLoadingDetails: false,
      );
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      String errorMessage = '과제 상세 정보를 불러오는데 실패했습니다: $e';
      if (e is CourseApiException) {
        errorMessage =
            '과제 정보 로드 실패: ${e.message} (statusCode: ${e.statusCode}, code: ${e.code})';
      }
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isLoadingDetails: false,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> _loadAssignmentSubmissionStatuses({
    required String courseSlug,
    required String assignmentId,
  }) async {
    state = state.copyWith(
      isLoadingSubmissionStatuses: true,
      clearAssignmentSubmissionStatuses: true,
      clearError: true,
    );
    try {
      final statuses = await ref.read(
        getAssignmentSubmissionStatusesUseCaseProvider,
      )(courseSlug: courseSlug, assignmentId: assignmentId);

      if (state.selectedCourse?.slug == courseSlug) {
        state = state.copyWith(
          selectedAssignmentSubmissionStatuses: statuses,
          isLoadingSubmissionStatuses: false,
        );
      }
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(
        isLoadingSubmissionStatuses: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _createAssignment({
    required String courseSlug,
    required CreateAssignmentRequest request,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      await ref.read(createAssignmentUseCaseProvider)(
        courseSlug: courseSlug,
        request: request,
      );

      state = state.copyWith(isCreating: false);
      add(TasksManagementAssignmentsRequested(courseSlug: courseSlug));
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isCreating: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _updateAssignment({
    required String courseSlug,
    required String assignmentId,
    required UpdateAssignmentRequest request,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      await ref.read(updateAssignmentUseCaseProvider)(
        courseSlug: courseSlug,
        assignmentId: assignmentId,
        request: request,
      );

      state = state.copyWith(isCreating: false);
      add(TasksManagementAssignmentsRequested(courseSlug: courseSlug));
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      String errorMessage = '과제 수정 중 오류가 발생했습니다: $e';
      if (e is CourseApiException) {
        errorMessage =
            '과제 수정 실패: ${e.message} (statusCode: ${e.statusCode}, code: ${e.code})';
      }
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isCreating: false,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> _deleteAssignment({
    required String courseSlug,
    required String assignmentId,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      await ref.read(deleteAssignmentUseCaseProvider)(
        courseSlug: courseSlug,
        assignmentId: assignmentId,
      );

      state = state.copyWith(isCreating: false);
      add(TasksManagementAssignmentsRequested(courseSlug: courseSlug));
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      String errorMessage = '과제 삭제 중 오류가 발생했습니다: $e';
      if (e is CourseApiException) {
        errorMessage =
            '과제 삭제 실패: ${e.message} (statusCode: ${e.statusCode}, code: ${e.code})';
      }
      state = state.copyWith(
        status: TasksManagementStatus.failure,
        isCreating: false,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> _deleteCourse({required String courseSlug}) async {
    state = state.copyWith(isDeleting: true, clearError: true);
    try {
      await ref.read(deleteCourseUseCaseProvider)(slug: courseSlug);

      // Remove from the list of courses
      final newCourses = state.courses
          .where((c) => c.slug != courseSlug)
          .toList();
      state = state.copyWith(isDeleting: false, courses: newCourses);
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(isDeleting: false, errorMessage: e.toString());
    }
  }

  Future<void> _updateCourse({
    required String courseSlug,
    required UpdateCourseRequest request,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final updated = await ref.read(updateCourseUseCaseProvider)(
        courseSlug: courseSlug,
        request: request,
      );

      // Replace in list
      final newCourses = state.courses
          .map<CourseSummary>((c) => c.slug == courseSlug ? updated : c)
          .toList();
      state = state.copyWith(
        isCreating: false,
        courses: newCourses,
        selectedCourse: updated,
      );
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(isCreating: false, errorMessage: e.toString());
    }
  }

  Future<void> _deleteEnrollment({
    required String courseSlug,
    required String userId,
  }) async {
    state = state.copyWith(isLoadingDetails: true, clearError: true);
    try {
      await ref
          .read(deleteEnrollmentUseCaseProvider)
          .execute(courseSlug: courseSlug, userId: userId);
      add(TasksManagementEnrollmentsRequested(courseSlug));
    } catch (e) {
      unawaited(showApiAlertIfPresent(e));
      state = state.copyWith(
        isLoadingDetails: false,
        errorMessage: '수강생 삭제 실패: $e',
      );
    }
  }

  Future<void> _searchUser({required String query}) async {
    if (query.isEmpty) {
      state = state.copyWith(clearSearchedUser: true, userNotFound: false);
      return;
    }

    state = state.copyWith(
      isSearchingUser: true,
      clearSearchedUser: true,
      userNotFound: false,
    );

    try {
      final repository = ref.read(usersManagementRepositoryProvider);
      final user = await repository.lookupUser(code: query);
      state = state.copyWith(
        isSearchingUser: false,
        searchedUser: user,
        userNotFound: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSearchingUser: false,
        clearSearchedUser: true,
        userNotFound: true,
      );
    }
  }
}
