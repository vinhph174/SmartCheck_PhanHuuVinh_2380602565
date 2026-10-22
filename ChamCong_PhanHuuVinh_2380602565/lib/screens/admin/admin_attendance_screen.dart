import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  List<AttendanceRecordModel> _records = [];
  bool _isLoading = true;
  String? _loadError;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    String url = ApiConfig.allAttendance;
    if (_statusFilter != null) {
      url += '?status=$_statusFilter';
    }

    final res = await ApiService.get(url);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          final list = res.data['records'] as List? ?? [];
          _records = list
              .map((r) => AttendanceRecordModel.fromJson(r))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải dữ liệu chấm công.';
        }
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? utcStr) {
    if (utcStr == null) return '--:--';
    try {
      final dt = DateTime.parse(utcStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} (${dt.day}/${dt.month})';
    } catch (_) {
      return utcStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Chấm công'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Lọc trạng thái',
            onSelected: (val) {
              setState(() => _statusFilter = val);
              _loadRecords();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: null,
                child: Text('Tất cả trạng thái'),
              ),
              const PopupMenuItem(value: 'OnTime', child: Text('Đúng giờ')),
              const PopupMenuItem(value: 'Late', child: Text('Đi muộn')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecords),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadRecords)
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
                  const Text('Chưa có bản ghi chấm công nào'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecords,
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
                              Expanded(
                                child: Text(
                                  item.employeeName ?? 'Nhân viên',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
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
                            'Mã: ${item.employeeCode ?? ''} • ${item.departmentName ?? 'Chưa phân phòng'}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
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
                                      'Ca làm:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      item.shiftName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Địa điểm:',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      item.locationName,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Chấm công vào:',
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
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Chấm công ra:',
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
                          if (item.checkInLatitude != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'GPS chấm công vào: ${item.checkInLatitude?.toStringAsFixed(4)}, ${item.checkInLongitude?.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
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
