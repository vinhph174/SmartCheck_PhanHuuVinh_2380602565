import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class AdminLocationSharesScreen extends StatefulWidget {
  const AdminLocationSharesScreen({super.key});

  @override
  State<AdminLocationSharesScreen> createState() =>
      _AdminLocationSharesScreenState();
}

class _AdminLocationSharesScreenState extends State<AdminLocationSharesScreen> {
  List<LocationShareModel> _locations = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final res = await ApiService.get(ApiConfig.latestLocations);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          final list = res.data['items'] as List? ?? [];
          _locations = list.map((l) => LocationShareModel.fromJson(l)).toList();
        } else {
          _loadError = res.message ?? 'Không thể tải lịch sử chia sẻ vị trí.';
        }
        _isLoading = false;
      });
    }
  }

  String _formatTime(String utcStr) {
    if (utcStr.isEmpty) return '--';
    try {
      final dt = DateTime.parse(utcStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ngày ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return utcStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vị trí Nhân viên đã chia sẻ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocations,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadLocations)
          : _locations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có nhân viên nào gửi vị trí GPS chia sẻ.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLocations,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _locations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _locations[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.teal.shade100,
                                child: Icon(
                                  Icons.my_location,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.fullName ?? 'Nhân viên',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Mã: ${item.employeeCode ?? ''} • ${item.departmentName ?? 'Chưa phân phòng'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.pin_drop,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tọa độ GPS: ${item.latitude.toStringAsFixed(6)}, ${item.longitude.toStringAsFixed(6)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (item.accuracyMeters != null)
                                  Text(
                                    'Độ chính xác: ±${item.accuracyMeters!.toStringAsFixed(1)}m',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cập nhật lúc: ${_formatTime(item.sharedAtUtc)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.note != null && item.note!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.notes,
                                  size: 16,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Ghi chú: ${item.note}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
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
