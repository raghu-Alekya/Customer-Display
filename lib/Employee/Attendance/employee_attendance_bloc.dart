import 'package:bloc/bloc.dart';

import 'employee_attendance_model.dart';
import 'employee_attendance_repository.dart';

sealed class EmployeeAttendanceEvent {
  const EmployeeAttendanceEvent();
}

class AttendanceLoadRequested extends EmployeeAttendanceEvent {
  const AttendanceLoadRequested(
      {required this.employeeCode, required this.date});
  final String employeeCode;
  final String date;
}

class AttendanceClockInRequested extends EmployeeAttendanceEvent {
  const AttendanceClockInRequested(
      {required this.employeeCode, required this.pin});
  final String employeeCode;
  final String pin;
}

class AttendanceClockOutRequested extends EmployeeAttendanceEvent {
  const AttendanceClockOutRequested(
      {required this.employeeCode, required this.pin});
  final String employeeCode;
  final String pin;
}

class EmployeeAttendanceState {
  const EmployeeAttendanceState({
    this.records = const {},
    this.loadedEmployeeCodes = const {},
    this.isLoading = false,
    this.submittingEmployeeCode,
    this.errorMessage,
    this.noticeMessage,
  });

  final Map<String, EmployeeAttendanceRecord> records;
  final Set<String> loadedEmployeeCodes;
  final bool isLoading;
  final String? submittingEmployeeCode;
  final String? errorMessage;
  final String? noticeMessage;

  EmployeeAttendanceState copyWith({
    Map<String, EmployeeAttendanceRecord>? records,
    Set<String>? loadedEmployeeCodes,
    bool? isLoading,
    String? submittingEmployeeCode,
    bool clearSubmittingEmployeeCode = false,
    String? errorMessage,
    bool clearError = false,
    String? noticeMessage,
    bool clearNotice = false,
  }) =>
      EmployeeAttendanceState(
        records: records ?? this.records,
        loadedEmployeeCodes: loadedEmployeeCodes ?? this.loadedEmployeeCodes,
        isLoading: isLoading ?? this.isLoading,
        submittingEmployeeCode: clearSubmittingEmployeeCode
            ? null
            : submittingEmployeeCode ?? this.submittingEmployeeCode,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
        noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
      );
}

class EmployeeAttendanceBloc
    extends Bloc<EmployeeAttendanceEvent, EmployeeAttendanceState> {
  EmployeeAttendanceBloc(this._repository)
      : super(const EmployeeAttendanceState()) {
    on<AttendanceLoadRequested>(_onLoad);
    on<AttendanceClockInRequested>(_onClockIn);
    on<AttendanceClockOutRequested>(_onClockOut);
  }

  final EmployeeAttendanceRepository _repository;

  Future<void> _onLoad(
      AttendanceLoadRequested event,
      Emitter<EmployeeAttendanceState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearNotice: true));
    try {
      final record = await _repository.getMyAttendanceForDate(
        employeeCode: event.employeeCode,
        date: event.date,
      );
      final records = Map<String, EmployeeAttendanceRecord>.from(state.records);
      if (record == null) {
        records.remove(event.employeeCode);
      } else {
        records[record.employeeCode] = record;
      }
      final loaded = Set<String>.from(state.loadedEmployeeCodes)
        ..add(event.employeeCode);
      emit(state.copyWith(
        records: records,
        loadedEmployeeCodes: loaded,
        isLoading: false,
      ));
    } catch (error) {
      emit(state.copyWith(isLoading: false, errorMessage: error.toString()));
    }
  }

  Future<void> _onClockIn(
      AttendanceClockInRequested event,
      Emitter<EmployeeAttendanceState> emit,
      ) async {
    await _clock(
      emit,
      employeeCode: event.employeeCode,
      action: () => _repository.clockIn(
        employeeCode: event.employeeCode,
        pin: event.pin,
      ),
      successMessage: 'Clock-in recorded.',
    );
  }

  Future<void> _onClockOut(
      AttendanceClockOutRequested event,
      Emitter<EmployeeAttendanceState> emit,
      ) async {
    await _clock(
      emit,
      employeeCode: event.employeeCode,
      action: () => _repository.clockOut(
        employeeCode: event.employeeCode,
        pin: event.pin,
      ),
      successMessage: 'Clock-out recorded.',
    );
  }

  Future<void> _clock(
      Emitter<EmployeeAttendanceState> emit, {
        required String employeeCode,
        required Future<EmployeeAttendanceRecord> Function() action,
        required String successMessage,
      }) async {
    emit(state.copyWith(
      submittingEmployeeCode: employeeCode,
      clearError: true,
      clearNotice: true,
    ));
    try {
      final record = await action();
      final records = Map<String, EmployeeAttendanceRecord>.from(state.records)
        ..[record.employeeCode] = record;
      final loaded = Set<String>.from(state.loadedEmployeeCodes)
        ..add(record.employeeCode);
      emit(state.copyWith(
        records: records,
        loadedEmployeeCodes: loaded,
        clearSubmittingEmployeeCode: true,
        noticeMessage: successMessage,
      ));
    } catch (error) {
      emit(state.copyWith(
        clearSubmittingEmployeeCode: true,
        errorMessage: error.toString(),
      ));
    }
  }
}
