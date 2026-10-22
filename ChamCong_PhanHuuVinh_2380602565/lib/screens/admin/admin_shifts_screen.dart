import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/form_validators.dart';
import '../../widgets/load_state_view.dart';

class AdminShiftsScreen extends StatefulWidget {
  const AdminShiftsScreen({super.key});

  @override
  State<AdminShiftsScreen> createState() => _AdminShiftsScreenState();
}

class _AdminShiftsScreenState extends State<AdminShiftsScreen> {
  List<ShiftModel> _shifts = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final res = await ApiService.get(ApiConfig.shifts);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is List) {
          _shifts = (res.data as List)
              .map((s) => ShiftModel.fromJson(s))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải danh sách ca làm việc.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEditDialog({ShiftModel? shift}) async {
    final nameController = TextEditingController(text: shift?.name ?? '');
    final graceController = TextEditingController(
      text: '${shift?.graceMinutes ?? 15}',
    );
    TimeOfDay startTime = shift != null
        ? _parseTime(shift.startTime)
        : const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = shift != null
        ? _parseTime(shift.endTime)
        : const TimeOfDay(hour: 17, minute: 0);
    bool isActive = shift?.isActive ?? true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(shift == null ? 'Thêm Ca làm việc' : 'Sửa Ca làm việc'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên ca * (VD: Ca sáng)',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giờ bắt đầu:'),
                  trailing: Text(
                    startTime.format(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (picked != null) {
                      setDialogState(() => startTime = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Giờ kết thúc:'),
                  trailing: Text(
                    endTime.format(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (picked != null) {
                      setDialogState(() => endTime = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: graceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số phút cho phép đi muộn (phút)',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang kích hoạt'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
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
                      final name = nameController.text.trim();
                      final validationError = FormValidators.shift(
                        name: name,
                        graceMinutes: graceController.text,
                        startMinutes: startTime.hour * 60 + startTime.minute,
                        endMinutes: endTime.hour * 60 + endTime.minute,
                      );
                      if (validationError != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(validationError),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      final grace = int.parse(graceController.text.trim());
                      setDialogState(() => isSaving = true);

                      final startStr =
                          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                      final endStr =
                          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                      final body = {
                        'name': name,
                        'startTime': startStr,
                        'endTime': endStr,
                        'graceMinutes': grace,
                        'isActive': isActive,
                      };

                      final res = shift == null
                          ? await ApiService.post(ApiConfig.shifts, body: body)
                          : await ApiService.put(
                              ApiConfig.shift(shift.id),
                              body: body,
                            );

                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadShifts();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                shift == null
                                    ? 'Thêm ca thành công'
                                    : 'Cập nhật thành công',
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
                              content: Text(res.message ?? 'Thao tác thất bại'),
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
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    graceController.dispose();
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }

  Future<void> _deleteShift(ShiftModel shift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa ca'),
        content: Text('Bạn có chắc muốn xóa ca làm "${shift.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.delete(ApiConfig.shift(shift.id));
      if (!mounted) return;
      if (res.isSuccess) {
        _loadShifts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa ca làm thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message ?? 'Không thể xóa ca làm đang có lịch phân công.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Ca làm việc')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadShifts)
          : _shifts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Chưa có ca làm việc nào'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadShifts,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _shifts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final shift = _shifts[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: shift.isActive
                            ? Colors.indigo.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.access_time_filled,
                          color: shift.isActive ? Colors.indigo : Colors.grey,
                        ),
                      ),
                      title: Text(
                        shift.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Thời gian: ${shift.startTime} - ${shift.endTime}\nDu di muộn: ${shift.graceMinutes} phút',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showAddEditDialog(shift: shift),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteShift(shift),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Thêm ca làm',
        child: const Icon(Icons.add),
      ),
    );
  }
}
