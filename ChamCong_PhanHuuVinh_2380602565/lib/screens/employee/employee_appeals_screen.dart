import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/display_text.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/form_validators.dart';
import '../../widgets/load_state_view.dart';

class EmployeeAppealsScreen extends StatefulWidget {
  const EmployeeAppealsScreen({super.key});

  @override
  State<EmployeeAppealsScreen> createState() => _EmployeeAppealsScreenState();
}

class _EmployeeAppealsScreenState extends State<EmployeeAppealsScreen> {
  List<AttendanceAppealModel> _myAppeals = [];
  List<ShiftAssignmentModel> _myAssignments = [];
  List<AppealSuggestionModel> _suggestions = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final resAppeals = await ApiService.get(ApiConfig.myAppeals);
    final resAssignments = await ApiService.get(ApiConfig.myAssignments);
    final resSuggestions = await ApiService.get(ApiConfig.appealSuggestions);

    if (mounted) {
      setState(() {
        if (resAppeals.isSuccess && resAppeals.data is Map<String, dynamic>) {
          final list = resAppeals.data['appeals'] as List? ?? [];
          _myAppeals = list
              .map((a) => AttendanceAppealModel.fromJson(a))
              .toList();
        }
        if (resAssignments.isSuccess &&
            resAssignments.data is Map<String, dynamic>) {
          final list = resAssignments.data['assignments'] as List? ?? [];
          _myAssignments = list
              .map((a) => ShiftAssignmentModel.fromJson(a))
              .toList();
        }
        if (resSuggestions.isSuccess &&
            resSuggestions.data is Map<String, dynamic>) {
          final list = resSuggestions.data['suggestions'] as List? ?? [];
          _suggestions = list
              .map((s) => AppealSuggestionModel.fromJson(s))
              .toList();
        }
        if (!resAppeals.isSuccess) {
          _loadError =
              resAppeals.message ?? 'Không thể tải danh sách giải trình.';
        } else if (!resAssignments.isSuccess) {
          _loadError = resAssignments.message ?? 'Không thể tải lịch làm việc.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateAppealDialog({
    int? initialShiftAssignmentId,
    String? initialReason,
  }) async {
    if (_myAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa có ca làm việc nào để giải trình.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int selectedAssignmentId =
        (initialShiftAssignmentId != null &&
            _myAssignments.any((a) => a.id == initialShiftAssignmentId))
        ? initialShiftAssignmentId
        : _myAssignments.first.id;

    final reasonController = TextEditingController(text: initialReason ?? '');
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.rate_review, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Gửi Giải trình Chấm công', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_suggestions.isNotEmpty) ...[
                  const Text(
                    '💡 Gợi ý tự động từ hệ thống:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _suggestions.map((sug) {
                      final isSelected =
                          selectedAssignmentId == sug.shiftAssignmentId;
                      return ActionChip(
                        avatar: const Icon(
                          Icons.bolt,
                          size: 16,
                          color: Colors.orange,
                        ),
                        label: Text(
                          '${sug.workDate}: ${sug.anomalyDescription}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? Colors.amber.shade100
                            : null,
                        onPressed: () {
                          setDialogState(() {
                            selectedAssignmentId = sug.shiftAssignmentId;
                            reasonController.text = sug.suggestedReason;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const Divider(height: 20),
                ],
                const Text(
                  'Chọn ca làm việc cần giải trình:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  initialValue: selectedAssignmentId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _myAssignments.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.workDate}: ${a.shiftName}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedAssignmentId = val!),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Lý do giải trình:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Nhập chi tiết lý do (VD: Xe hỏng, thiết bị mất mạng, ...)',
                  ),
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
                      final reason = reasonController.text.trim();
                      final validationError = FormValidators.appealReason(
                        reason,
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

                      setDialogState(() => isSubmitting = true);

                      final body = {
                        'shiftAssignmentId': selectedAssignmentId,
                        'reason': reason,
                      };

                      final res = await ApiService.post(
                        ApiConfig.appeals,
                        body: body,
                      );
                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã gửi yêu cầu giải trình thành công!',
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
                              content: Text(
                                res.message ?? 'Không thể gửi giải trình.',
                              ),
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
                  : const Text('Gửi giải trình'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
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

  Widget _buildSuggestionsBanner() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Colors.amber.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Phát hiện ${_suggestions.length} ca cần giải trình',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.brown.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Hệ thống tự động phát hiện các ca làm việc bị đi muộn hoặc chưa hoàn tất chấm công ra ca:',
              style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
            ),
            const SizedBox(height: 10),
            ..._suggestions.map((sug) {
              IconData icon = Icons.schedule;
              Color iconColor = Colors.orange;
              if (sug.anomalyType == 'MissingCheckOut') {
                icon = Icons.logout;
                iconColor = Colors.red;
              } else if (sug.anomalyType == 'MissedShift') {
                icon = Icons.event_busy;
                iconColor = Colors.purple;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${sug.workDate}: ${sug.shiftName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            sug.anomalyDescription,
                            style: TextStyle(
                              fontSize: 12,
                              color: iconColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showCreateAppealDialog(
                        initialShiftAssignmentId: sug.shiftAssignmentId,
                        initialReason: sug.suggestedReason,
                      ),
                      child: const Text('Tạo đơn'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giải trình Chấm công'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadData)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSuggestionsBanner(),
                  if (_suggestions.isNotEmpty) const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh sách đơn giải trình (${_myAppeals.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_myAppeals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.edit_note,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bạn chưa có đơn giải trình nào.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._myAppeals.map((item) {
                      Color statusColor = Colors.orange;
                      if (item.status == 'Approved') {
                        statusColor = Colors.green;
                      } else if (item.status == 'Rejected') {
                        statusColor = Colors.red;
                      }
                      final statusText = DisplayText.appealStatus(item.status);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      color: statusColor.withValues(
                                        alpha: 0.12,
                                      ),
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
                              const SizedBox(height: 4),
                              Text(
                                'Ngày làm: ${item.workDate} • Điểm: ${item.locationName}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  'Lý do: "${item.reason}"',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (item.reviewNote != null &&
                                  item.reviewNote!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Phản hồi từ quản trị viên: ${item.reviewNote}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                'Gửi lúc: ${_formatTime(item.submittedAtUtc)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAppealDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Gửi giải trình mới'),
      ),
    );
  }
}
