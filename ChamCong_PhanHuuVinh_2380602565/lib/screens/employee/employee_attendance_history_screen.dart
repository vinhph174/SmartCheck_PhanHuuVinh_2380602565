import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class EmployeeAttendanceHistoryScreen extends StatefulWidget {
  const EmployeeAttendanceHistoryScreen({super.key});

  @override
  State<EmployeeAttendanceHistoryScreen> createState() =>
      _EmployeeAttendanceHistoryScreenState();
}

class _EmployeeAttendanceHistoryScreenState
    extends State<EmployeeAttendanceHistoryScreen> {
  List<AttendanceRecordModel> _records = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final res = await ApiService.get(ApiConfig.myAttendance);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          final list = res.data['records'] as List? ?? [];
          _records = list
              .map((r) => AttendanceRecordModel.fromJson(r))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải lịch sử chấm công.';
        }
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? utcStr) {
    if (utcStr == null) return '--:--';
    try {
      final dt = DateTime.parse(utcStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ngày ${dt.day}/${dt.month}';
    } catch (_) {
      return utcStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Chấm công của tôi'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadHistory)
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('Bạn chưa có bản ghi chấm công nào.'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _records[index];
                  final isLate = item.checkInStatus == 'Late';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.shiftName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isLate
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isLate ? 'Đi muộn' : 'Đúng giờ',
                                  style: TextStyle(
                                    color: isLate
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ngày làm: ${item.workDate} • Điểm: ${item.locationName}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Giờ chấm công vào:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(item.checkInUtc),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Giờ chấm công ra:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _formatTime(item.checkOutUtc),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
