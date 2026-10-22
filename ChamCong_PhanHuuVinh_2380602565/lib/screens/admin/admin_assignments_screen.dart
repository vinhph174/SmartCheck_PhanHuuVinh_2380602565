import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../config/display_text.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class AdminAssignmentsScreen extends StatefulWidget {
  const AdminAssignmentsScreen({super.key});

  @override
  State<AdminAssignmentsScreen> createState() => _AdminAssignmentsScreenState();
}

class _AdminAssignmentsScreenState extends State<AdminAssignmentsScreen> {
  List<ShiftAssignmentModel> _assignments = [];
  List<EmployeeModel> _employees = [];
  List<ShiftModel> _shifts = [];
  List<WorkLocationModel> _locations = [];
  DateTime _filterDate = DateTime.now();
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final dateStr =
        '${_filterDate.year}-${_filterDate.month.toString().padLeft(2, '0')}-${_filterDate.day.toString().padLeft(2, '0')}';
    final resAssignments = await ApiService.get(
      '${ApiConfig.shiftAssignments}?workDate=$dateStr',
    );
    final resEmployees = await ApiService.get(
      '${ApiConfig.adminEmployees}?isActive=true',
    );
    final resShifts = await ApiService.get(ApiConfig.shifts);
    final resLocations = await ApiService.get(ApiConfig.locations);

    if (mounted) {
      setState(() {
        if (resAssignments.isSuccess &&
            resAssignments.data is Map<String, dynamic>) {
          final list = resAssignments.data['assignments'] as List? ?? [];
          _assignments = list
              .map((a) => ShiftAssignmentModel.fromJson(a))
              .toList();
        }
        if (resEmployees.isSuccess &&
            resEmployees.data is Map<String, dynamic>) {
          final list = resEmployees.data['employees'] as List? ?? [];
          _employees = list.map((e) => EmployeeModel.fromJson(e)).toList();
        }
        if (resShifts.isSuccess && resShifts.data is List) {
          _shifts = (resShifts.data as List)
              .map((s) => ShiftModel.fromJson(s))
              .where((s) => s.isActive)
              .toList();
        }
        if (resLocations.isSuccess && resLocations.data is List) {
          _locations = (resLocations.data as List)
              .map((l) => WorkLocationModel.fromJson(l))
              .where((l) => l.isActive)
              .toList();
        }
        if (!resAssignments.isSuccess) {
          _loadError = resAssignments.message ?? 'Không thể tải lịch phân ca.';
        } else if (!resEmployees.isSuccess) {
          _loadError =
              resEmployees.message ?? 'Không thể tải danh sách nhân viên.';
        } else if (!resShifts.isSuccess) {
          _loadError =
              resShifts.message ?? 'Không thể tải danh sách ca làm việc.';
        } else if (!resLocations.isSuccess) {
          _loadError =
              resLocations.message ?? 'Không thể tải danh sách địa điểm.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEditDialog({ShiftAssignmentModel? assignment}) async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có nhân viên hoạt động nào để phân ca.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_shifts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có ca làm việc nào. Vui lòng tạo ca trước.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có địa điểm làm việc nào. Vui lòng tạo địa điểm trước.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (assignment != null &&
        (!_employees.any((e) => e.employeeId == assignment.employeeId) ||
            !_shifts.any((s) => s.id == assignment.shiftId) ||
            !_locations.any((l) => l.id == assignment.workLocationId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể sửa vì nhân viên, ca hoặc địa điểm đã bị vô hiệu hóa.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int selectedEmployeeId =
        assignment?.employeeId ?? _employees.first.employeeId;
    int selectedShiftId = assignment?.shiftId ?? _shifts.first.id;
    int selectedLocationId = assignment?.workLocationId ?? _locations.first.id;
    DateTime selectedDate = assignment != null
        ? DateTime.parse(assignment.workDate)
        : _filterDate;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(
            assignment == null ? 'Phân công ca mới' : 'Chỉnh sửa phân công',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn nhân viên:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedEmployeeId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _employees
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.employeeId,
                          child: Text('${e.fullName} (${e.employeeCode})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedEmployeeId = val!),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chọn ca làm:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedShiftId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _shifts
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name} (${s.startTime} - ${s.endTime})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedShiftId = val!),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chọn địa điểm làm việc:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedLocationId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _locations
                      .map(
                        (l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.name)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedLocationId = val!),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ngày làm việc:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final dateFormatted =
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                      final body = {
                        'employeeId': selectedEmployeeId,
                        'shiftId': selectedShiftId,
                        'workLocationId': selectedLocationId,
                        'workDate': dateFormatted,
                      };

                      final res = assignment == null
                          ? await ApiService.post(
                              ApiConfig.shiftAssignments,
                              body: body,
                            )
                          : await ApiService.put(
                              ApiConfig.shiftAssignment(assignment.id),
                              body: body,
                            );

                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) setState(() => _filterDate = selectedDate);
                        _loadAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                assignment == null
                                    ? 'Phân ca thành công!'
                                    : 'Cập nhật phân ca thành công!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (ctx.mounted) setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res.message ??
                                    (assignment == null
                                        ? 'Phân ca thất bại.'
                                        : 'Không thể cập nhật phân ca.'),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(assignment == null ? 'Phân công' : 'Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAssignment(ShiftAssignmentModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận hủy phân ca'),
        content: Text(
          'Bạn có chắc muốn hủy phân ca của ${item.employeeName} vào ngày ${item.workDate}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hủy phân ca'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.delete(ApiConfig.shiftAssignment(item.id));
      if (!mounted) return;
      if (res.isSuccess) {
        _loadAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hủy phân ca thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Không thể xóa phân ca.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phân công Ca làm')),
      body: Column(
        children: [
          // Date selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(
                      () => _filterDate = _filterDate.subtract(
                        const Duration(days: 1),
                      ),
                    );
                    _loadAll();
                  },
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _filterDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _filterDate = picked);
                      _loadAll();
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: Color(0xFF1E40AF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_filterDate.day.toString().padLeft(2, '0')}/${_filterDate.month.toString().padLeft(2, '0')}/${_filterDate.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(
                      () => _filterDate = _filterDate.add(
                        const Duration(days: 1),
                      ),
                    );
                    _loadAll();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? LoadErrorView(message: _loadError!, onRetry: _loadAll)
                : _assignments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có ca làm việc nào được phân công trong ngày này',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _assignments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _assignments[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.hasAttendance
                                  ? Colors.green.shade100
                                  : Colors.blue.shade100,
                              child: Icon(
                                item.hasAttendance
                                    ? Icons.check
                                    : Icons.schedule,
                                color: item.hasAttendance
                                    ? Colors.green
                                    : Colors.blue,
                              ),
                            ),
                            title: Text(
                              item.employeeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${item.shiftName} (${item.startTime} - ${item.endTime})\nĐịa điểm: ${item.locationName} | Trạng thái: ${DisplayText.shiftStatus(item.status)}',
                            ),
                            isThreeLine: true,
                            trailing: item.status == 'Scheduled'
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _showAddEditDialog(assignment: item);
                                      } else if (value == 'delete') {
                                        _deleteAssignment(item);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Chỉnh sửa'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          'Hủy phân ca',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEditDialog,
        icon: const Icon(Icons.add),
        label: const Text('Phân ca mới'),
      ),
    );
  }
}
