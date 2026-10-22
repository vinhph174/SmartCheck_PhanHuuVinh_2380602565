import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/display_text.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class AdminAppealsScreen extends StatefulWidget {
  const AdminAppealsScreen({super.key});

  @override
  State<AdminAppealsScreen> createState() => _AdminAppealsScreenState();
}

class _AdminAppealsScreenState extends State<AdminAppealsScreen> {
  List<AttendanceAppealModel> _appeals = [];
  bool _isLoading = true;
  String? _loadError;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    String url = ApiConfig.appeals;
    if (_statusFilter != null) {
      url += '?status=$_statusFilter';
    }

    final res = await ApiService.get(url);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          final list = res.data['appeals'] as List? ?? [];
          _appeals = list
              .map((a) => AttendanceAppealModel.fromJson(a))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải danh sách giải trình.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showReviewDialog(AttendanceAppealModel appeal) async {
    String decision = 'Approved';
    final noteController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('Phê duyệt Giải trình'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nhân viên: ${appeal.employeeName ?? ''} (${appeal.employeeCode ?? ''})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Ca: ${appeal.shiftName} - Ngày: ${appeal.workDate}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    'Lý do giải trình:\n"${appeal.reason}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quyết định:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Phê duyệt')),
                        selected: decision == 'Approved',
                        selectedColor: Colors.green.shade100,
                        onSelected: (val) {
                          if (val) setDialogState(() => decision = 'Approved');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Từ chối')),
                        selected: decision == 'Rejected',
                        selectedColor: Colors.red.shade100,
                        onSelected: (val) {
                          if (val) setDialogState(() => decision = 'Rejected');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú / Nhận xét của quản trị viên',
                    hintText: 'VD: Chấp nhận giải trình do sự cố giao thông',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      final body = {
                        'status': decision,
                        'reviewNote': noteController.text.trim(),
                      };
                      final res = await ApiService.put(
                        ApiConfig.reviewAppeal(appeal.id),
                        body: body,
                      );

                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadAppeals();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Đã ${decision == 'Approved' ? 'phê duyệt' : 'từ chối'} giải trình!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message ?? 'Lỗi xử lý'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
  }

  String _formatTime(String utcStr) {
    if (utcStr.isEmpty) return '--';
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
        title: const Text('Duyệt Giải trình Chấm công'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (val) {
              setState(() => _statusFilter = val);
              _loadAppeals();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: null, child: Text('Tất cả')),
              const PopupMenuItem(value: 'Pending', child: Text('Chờ duyệt')),
              const PopupMenuItem(
                value: 'Approved',
                child: Text('Đã phê duyệt'),
              ),
              const PopupMenuItem(value: 'Rejected', child: Text('Đã từ chối')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAppeals),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadAppeals)
          : _appeals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('Không có yêu cầu giải trình nào'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAppeals,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _appeals.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _appeals[index];
                  Color statusColor = Colors.orange;
                  if (item.status == 'Approved') {
                    statusColor = Colors.green;
                  } else if (item.status == 'Rejected') {
                    statusColor = Colors.red;
                  }
                  final statusText = DisplayText.appealStatus(item.status);

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
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mã: ${item.employeeCode ?? ''} • Ca: ${item.shiftName} (${item.workDate})',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              'Lý do: "${item.reason}"',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (item.reviewNote != null &&
                              item.reviewNote!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Nhận xét của quản trị viên: ${item.reviewNote}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Gửi lúc: ${_formatTime(item.submittedAtUtc)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                              if (item.status == 'Pending')
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 34),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed: () => _showReviewDialog(item),
                                  child: const Text(
                                    'Xem & Duyệt',
                                    style: TextStyle(fontSize: 12),
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
