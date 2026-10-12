import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'employee_attendance_bloc.dart';
import 'employee_attendance_model.dart';
import 'employee_attendance_repository.dart';

/// API-backed version of the local attendance dialog.
class EmployeeAttendanceApiPopup extends StatelessWidget {
  const EmployeeAttendanceApiPopup({
    super.key,
    required this.employees,
    required this.currentEmployeeCode,
    required this.repository,
    this.currentEmployeePin,
  });

  final List<AttendanceEmployee> employees;
  final String currentEmployeeCode;
  final String? currentEmployeePin;
  final EmployeeAttendanceRepository repository;

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return BlocProvider(
      create: (_) {
        final bloc = EmployeeAttendanceBloc(repository);

        // 1. Restore all cached records into the bloc state
        final cached = EmployeeAttendanceRepository.cachedRecords;
        if (cached.isNotEmpty) {
          bloc.emit(bloc.state.copyWith(
            records: {...bloc.state.records, ...cached},
            loadedEmployeeCodes: {
              ...bloc.state.loadedEmployeeCodes,
              ...cached.keys,
            },
          ));
        }

        // 2. Fetch fresh attendance for the authenticated POS user
        bloc.add(AttendanceLoadRequested(
          employeeCode: currentEmployeeCode,
          date: today,
        ));

        // 3. Auto clock-in logged-in user if PIN provided and not yet clocked in
        if (currentEmployeePin != null &&
            currentEmployeePin!.isNotEmpty &&
            !(cached[currentEmployeeCode]?.isOpen ?? false)) {
          bloc.add(AttendanceClockInRequested(
            employeeCode: currentEmployeeCode,
            pin: currentEmployeePin!,
          ));
        }

        return bloc;
      },
      child: _EmployeeAttendanceDialog(
        employees: employees,
        currentEmployeeCode: currentEmployeeCode,
      ),
    );
  }
}

class _EmployeeAttendanceDialog extends StatefulWidget {
  const _EmployeeAttendanceDialog({
    required this.employees,
    required this.currentEmployeeCode,
  });

  final List<AttendanceEmployee> employees;
  final String currentEmployeeCode;

  @override
  State<_EmployeeAttendanceDialog> createState() =>
      _EmployeeAttendanceDialogState();
}

class _EmployeeAttendanceDialogState extends State<_EmployeeAttendanceDialog> {
  AttendanceEmployee? _selectedEmployee;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.max(340.0, math.min(1080.0, size.width - 40));
    final height = math.max(400.0, math.min(920.0, size.height - 40));

    return BlocListener<EmployeeAttendanceBloc, EmployeeAttendanceState>(
      listenWhen: (previous, current) =>
      previous.errorMessage != current.errorMessage ||
          previous.noticeMessage != current.noticeMessage,
      listener: (context, state) {
        String? message = state.errorMessage ?? state.noticeMessage;
        Color bgColor = state.errorMessage == null
            ? const Color(0xFF16834B)
            : const Color(0xFFB42318);

        // Handle 409 Conflict gracefully: Employee is already clocked in
        if (state.errorMessage != null &&
            state.errorMessage!.toLowerCase().contains('open attendance session')) {
          message = 'Employee is already clocked in today.';
          bgColor = const Color(0xFF16834B);

          final targetEmp = _selectedEmployee ??
              widget.employees.firstWhere(
                    (e) => e.employeeCode == widget.currentEmployeeCode,
              );

          final openRecord = EmployeeAttendanceRecord(
            id: 'open-${targetEmp.employeeCode}',
            employeeCode: targetEmp.employeeCode,
            employeeName: targetEmp.name,
            clockIn: DateTime.now(),
            status: 'PRESENT',
          );

          EmployeeAttendanceRepository.cacheRecord(openRecord);

          context.read<EmployeeAttendanceBloc>().emit(
            state.copyWith(
              records: {...state.records, targetEmp.employeeCode: openRecord},
              loadedEmployeeCodes: {
                ...state.loadedEmployeeCodes,
                targetEmp.employeeCode,
              },
              errorMessage: null,
            ),
          );
        }

        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
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
                BlocBuilder<EmployeeAttendanceBloc, EmployeeAttendanceState>(
                  builder: (context, state) => _topBarAction(context, state),
                ),
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
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (widget.employees.isEmpty) {
                        return const Center(
                          child: Text('No employees found for this store.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: widget.employees.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                        itemBuilder: (context, index) => _employeeCard(
                          context,
                          state,
                          widget.employees[index],
                        ),
                      );
                    },
                  ),
                ),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: OutlinedButton.icon(
                //     onPressed: () => Navigator.of(context).pop(false),
                //     icon: const Icon(Icons.close, size: 18),
                //     label: const Text('Close'),
                //   ),
                // ),
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
        child: const Icon(Icons.fact_check_outlined,
            color: Color(0xFF1E2745)),
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

  Widget _topBarAction(BuildContext context, EmployeeAttendanceState state) {
    if (widget.employees.isEmpty) return const SizedBox.shrink();

    final selectedRecord = _selectedEmployee != null
        ? state.records[_selectedEmployee!.employeeCode]
        : null;
    final isSelectedOpen = selectedRecord?.isOpen ?? false;
    final isSubmitting = _selectedEmployee != null &&
        state.submittingEmployeeCode == _selectedEmployee!.employeeCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_search_outlined,
              color: Color(0xFF3B65B3), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AttendanceEmployee>(
                isExpanded: true,
                value: _selectedEmployee,
                hint: const Text(
                  'Select team member to mark attendance...',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
                items: widget.employees.map((emp) {
                  final isCurrent =
                      emp.employeeCode == widget.currentEmployeeCode;
                  final record = state.records[emp.employeeCode];
                  final statusText = record?.isOpen == true
                      ? ' · [Present]'
                      : record?.status == 'COMPLETED'
                      ? ' · [Completed]'
                      : '';

                  return DropdownMenuItem(
                    value: emp,
                    child: Text(
                      '${emp.name} (${emp.employeeCode}) · ${emp.roleName ?? "Staff"}$statusText${isCurrent ? " (You)" : ""}',
                      style: TextStyle(
                        fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: const Color(0xFF1E293B),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (selected) {
                  setState(() => _selectedEmployee = selected);
                },
              ),
            ),
          ),
          if (_selectedEmployee != null) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16834B),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: !_selectedEmployee!.isRegistered ||
                  isSubmitting ||
                  isSelectedOpen
                  ? null
                  : () => _askPinAndClock(context, _selectedEmployee!,
                  isClockIn: true),
              icon: const Icon(Icons.login, size: 16),
              label: const Text('Clock In'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: !_selectedEmployee!.isRegistered ||
                  isSubmitting ||
                  !isSelectedOpen
                  ? null
                  : () => _askPinAndClock(context, _selectedEmployee!,
                  isClockIn: false),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Clock Out'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summary() =>
      BlocBuilder<EmployeeAttendanceBloc, EmployeeAttendanceState>(
        builder: (context, state) {
          final present =
              state.records.values.where((r) => r.isOpen).length;
          final completed =
              state.records.values.where((r) => r.status == 'COMPLETED').length;
          final notMarked = widget.employees
              .where((e) => !state.records.containsKey(e.employeeCode))
              .length;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryCard('Employees', widget.employees.length,
                  const Color(0xFF3B65B3)),
              _summaryCard('Present', present, const Color(0xFF16834B)),
              _summaryCard('Completed', completed, const Color(0xFF3B65B3)),
              _summaryCard('Not marked', notMarked, const Color(0xFFD98212)),
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
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF727C8B), fontSize: 12)),
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
    final isSubmitting =
        state.submittingEmployeeCode == employee.employeeCode;
    final isCurrent = employee.employeeCode == widget.currentEmployeeCode;

    final label = record == null
        ? 'Not marked'
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
        color: isCurrent
            ? const Color(0xFF3B65B3).withValues(alpha: 0.03)
            : Colors.transparent,
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF3B65B3).withValues(alpha: 0.4)
              : const Color(0xFFE5E9EF),
        ),
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              employee.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 4),
                            const Text('(You)',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF3B65B3),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      Text(
                        '${employee.employeeCode}${employee.roleName != null ? ' · ${employee.roleName}' : ''}',
                        style: const TextStyle(
                            color: Color(0xFF727C8B), fontSize: 12),
                      ),
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
                    : () => _askPinAndClock(context, employee,
                    isClockIn: true),
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
                    : () => _askPinAndClock(context, employee,
                    isClockIn: false),
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

    // Always empty fresh controller - never prefill old PIN
    final controller = TextEditingController();

    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            '${isClockIn ? 'Clock in' : 'Clock out'} · ${employee.name}'),
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
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
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
        const SnackBar(
            content: Text('Enter a PIN between 4 and 8 digits.')),
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