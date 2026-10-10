import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'employee_attendance_bloc.dart';
import 'employee_attendance_model.dart';
import 'employee_attendance_repository.dart';

/// API-backed version of the local attendance demo. Supply employees from the
/// app's existing employee API; this widget does not invent a roster.
class EmployeeAttendanceApiPopup extends StatelessWidget {
  const EmployeeAttendanceApiPopup({
    super.key,
    required this.employees,
    required this.currentEmployeeCode,
    required this.repository,
  });

  final List<AttendanceEmployee> employees;
  final String currentEmployeeCode;
  final EmployeeAttendanceRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmployeeAttendanceBloc(repository)
        ..add(AttendanceLoadRequested(
          employeeCode: currentEmployeeCode,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        )),
      child: _EmployeeAttendanceDialog(
        employees: employees,
        currentEmployeeCode: currentEmployeeCode,
      ),
    );
  }
}

class _EmployeeAttendanceDialog extends StatelessWidget {
  const _EmployeeAttendanceDialog({
    required this.employees,
    required this.currentEmployeeCode,
  });

  final List<AttendanceEmployee> employees;
  final String currentEmployeeCode;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.max(300.0, math.min(1080.0, size.width - 40));
    final height = math.max(360.0, math.min(900.0, size.height - 40));

    return BlocListener<EmployeeAttendanceBloc, EmployeeAttendanceState>(
      listenWhen: (previous, current) =>
      previous.errorMessage != current.errorMessage ||
          previous.noticeMessage != current.noticeMessage,
      listener: (context, state) {
        final message = state.errorMessage ?? state.noticeMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: state.errorMessage == null
                ? const Color(0xFF16834B)
                : const Color(0xFFB42318),
            behavior: SnackBarBehavior.floating,
          ));
      },
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 12),
                Text(
                  'Today · ${DateFormat('EEE, d MMM yyyy').format(DateTime.now())}',
                  style: const TextStyle(color: Color(0xFF727C8B)),
                ),
                const SizedBox(height: 12),
                _summary(),
                const SizedBox(height: 14),
                const Text(
                  'Team attendance',
                  style: TextStyle(
                    color: Color(0xFF1E2745),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: BlocBuilder<EmployeeAttendanceBloc,
                      EmployeeAttendanceState>(
                    builder: (context, state) {
                      if (state.isLoading && state.records.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.errorMessage != null && state.records.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(state.errorMessage!,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => context
                                    .read<EmployeeAttendanceBloc>()
                                    .add(AttendanceLoadRequested(
                                  employeeCode: currentEmployeeCode,
                                  date: DateFormat('yyyy-MM-dd')
                                      .format(DateTime.now()),
                                )),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }
                      if (employees.isEmpty) {
                        return const Center(
                          child: Text(
                              'No employees were supplied by the employee API.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: employees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _employeeCard(
                          context,
                          state,
                          employees[index],
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Row(
    children: [
      Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2745).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child:
        const Icon(Icons.fact_check_outlined, color: Color(0xFF1E2745)),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Text(
          'Employee Attendance',
          style: TextStyle(
            color: Color(0xFF1E2745),
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Close attendance',
        onPressed: () => Navigator.of(context).pop(false),
        icon: const Icon(Icons.close, color: Color(0xFF727C8B)),
      ),
    ],
  );

  Widget _summary() =>
      BlocBuilder<EmployeeAttendanceBloc, EmployeeAttendanceState>(
        builder: (context, state) {
          final present = state.records.values.where((r) => r.isOpen).length;
          final completed =
              state.records.values.where((r) => r.status == 'COMPLETED').length;
          final notMarked = employees
              .where((e) =>
          state.loadedEmployeeCodes.contains(e.employeeCode) &&
              !state.records.containsKey(e.employeeCode))
              .length;
          final notLoaded = employees
              .where((e) => !state.loadedEmployeeCodes.contains(e.employeeCode))
              .length;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryCard(
                  'Employees', employees.length, const Color(0xFF3B65B3)),
              _summaryCard('Present', present, const Color(0xFF16834B)),
              _summaryCard('Completed', completed, const Color(0xFF3B65B3)),
              _summaryCard('Not marked', notMarked, const Color(0xFFD98212)),
              _summaryCard('Not loaded', notLoaded, const Color(0xFF727C8B)),
            ],
          );
        },
      );

  Widget _summaryCard(String label, int value, Color color) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Color(0xFF727C8B), fontSize: 12)),
      ],
    ),
  );

  Widget _employeeCard(
      BuildContext context,
      EmployeeAttendanceState state,
      AttendanceEmployee employee,
      ) {
    final record = state.records[employee.employeeCode];
    final isOpen = record?.isOpen ?? false;
    final isSubmitting = state.submittingEmployeeCode == employee.employeeCode;
    final label = record == null
        ? (state.loadedEmployeeCodes.contains(employee.employeeCode)
        ? 'Not marked'
        : 'Not loaded')
        : switch (record.status) {
      'PRESENT' => 'Present',
      'COMPLETED' => 'Completed',
      _ => record.status,
    };
    final color = isOpen
        ? const Color(0xFF16834B)
        : record == null
        ? const Color(0xFFD98212)
        : const Color(0xFF3B65B3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E9EF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 250,
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(_initials(employee.name)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(employee.employeeCode,
                          style: const TextStyle(
                              color: Color(0xFF727C8B), fontSize: 12)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: !employee.isRegistered || isSubmitting || isOpen
                    ? null
                    : () => _askPinAndClock(context, employee, isClockIn: true),
                icon: isSubmitting
                    ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.login, size: 17),
                label: const Text('Clock In'),
              ),
              FilledButton.tonalIcon(
                onPressed: !employee.isRegistered || isSubmitting || !isOpen
                    ? null
                    : () =>
                    _askPinAndClock(context, employee, isClockIn: false),
                icon: const Icon(Icons.logout, size: 17),
                label: const Text('Clock Out'),
              ),
            ],
          ),
          if (record != null)
            Wrap(
              spacing: 16,
              children: [
                Text(
                    'In: ${DateFormat('h:mm a').format(record.clockIn.toLocal())}'),
                Text(
                    'Out: ${record.clockOut == null ? '—' : DateFormat('h:mm a').format(record.clockOut!.toLocal())}'),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _askPinAndClock(
      BuildContext context,
      AttendanceEmployee employee, {
        required bool isClockIn,
      }) async {
    if (!employee.isRegistered) return;
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
        Text('${isClockIn ? 'Clock in' : 'Clock out'} · ${employee.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(
            labelText: 'Employee PIN',
            counterText: '',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || pin == null) return;
    if (pin.length < 4 || pin.length > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a PIN between 4 and 8 digits.')),
      );
      return;
    }
    final bloc = context.read<EmployeeAttendanceBloc>();
    if (isClockIn) {
      bloc.add(AttendanceClockInRequested(
        employeeCode: employee.employeeCode,
        pin: pin,
      ));
    } else {
      bloc.add(AttendanceClockOutRequested(
        employeeCode: employee.employeeCode,
        pin: pin,
      ));
    }
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}
