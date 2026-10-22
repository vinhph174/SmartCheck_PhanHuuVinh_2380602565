import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../config/display_text.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';
import 'employee_attendance_action_screen.dart';

class EmployeeScheduleScreen extends StatefulWidget {
  const EmployeeScheduleScreen({super.key});

  @override
  State<EmployeeScheduleScreen> createState() => _EmployeeScheduleScreenState();
}

class _EmployeeScheduleScreenState extends State<EmployeeScheduleScreen> {
  List<ShiftAssignmentModel> _assignments = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final res = await ApiService.get(ApiConfig.myAssignments);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          final list = res.data['assignments'] as List? ?? [];
          _assignments = list
              .map((a) => ShiftAssignmentModel.fromJson(a))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải lịch làm việc.';
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch làm việc của tôi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSchedule),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadSchedule)
          : _assignments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('Bạn chưa có ca làm việc nào được phân công.'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadSchedule,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _assignments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _assignments[index];
                  final isToday = item.workDate == todayStr;
                  Color statusColor = Colors.blue;
                  if (item.status == 'InProgress') statusColor = Colors.orange;
                  if (item.status == 'Completed') statusColor = Colors.green;

                  return Card(
                    elevation: isToday ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isToday
                          ? const BorderSide(
                              color: Color(0xFF1E40AF),
                              width: 1.5,
                            )
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    color: Color(0xFF1E40AF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.workDate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (isToday) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Hôm nay',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF1E40AF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  DisplayText.shiftStatus(item.status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Text(
                            item.shiftName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Thời gian: ${item.startTime} - ${item.endTime} (Du di ${item.graceMinutes ?? 5} phút)',
                          ),
                          Text('Địa điểm: ${item.locationName}'),
                          if (item.locationAddress != null)
                            Text(
                              'Địa chỉ: ${item.locationAddress}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          if (isToday && item.status != 'Completed') ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            EmployeeAttendanceActionScreen(
                                              assignment: item,
                                            ),
                                      ),
                                    )
                                    .then((_) => _loadSchedule());
                              },
                              icon: const Icon(Icons.qr_code_scanner),
                              label: Text(
                                item.status == 'InProgress'
                                    ? 'Chấm công ra'
                                    : 'Chấm công vào',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
