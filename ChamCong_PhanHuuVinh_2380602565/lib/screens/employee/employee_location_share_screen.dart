import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class EmployeeLocationShareScreen extends StatefulWidget {
  const EmployeeLocationShareScreen({super.key});

  @override
  State<EmployeeLocationShareScreen> createState() =>
      _EmployeeLocationShareScreenState();
}

class _EmployeeLocationShareScreenState
    extends State<EmployeeLocationShareScreen> {
  bool _isSharingEnabled = false;
  Position? _currentPosition;
  final _noteController = TextEditingController();
  List<LocationShareModel> _myHistory = [];
  bool _isLoadingGps = false;
  bool _isSending = false;
  bool _isLoadingHistory = true;
  String? _error;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    final res = await ApiService.get(ApiConfig.myLocationShares);
    if (mounted) {
      if (res.isSuccess && res.data is Map<String, dynamic>) {
        final list = res.data['items'] as List? ?? [];
        setState(() {
          _myHistory = list.map((l) => LocationShareModel.fromJson(l)).toList();
          _isLoadingHistory = false;
        });
      } else {
        setState(() {
          _historyError =
              res.message ?? 'Không thể tải lịch sử chia sẻ vị trí.';
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _fetchCurrentGps() async {
    setState(() {
      _isLoadingGps = true;
      _error = null;
    });

    try {
      final pos = await LocationService.getCurrentPosition();
      if (mounted && _isSharingEnabled) {
        setState(() {
          _currentPosition = pos;
          _isLoadingGps = false;
        });
      }
    } catch (e) {
      if (mounted && _isSharingEnabled) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoadingGps = false;
        });
      }
    }
  }

  Future<void> _sendLocation() async {
    if (!_isSharingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng bật chia sẻ vị trí trước khi gửi.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _isLoadingGps = true;
      _error = null;
    });

    Position? freshPosition;
    try {
      freshPosition = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (!_isSharingEnabled) {
        setState(() {
          _isSending = false;
          _isLoadingGps = false;
          _currentPosition = null;
        });
        return;
      }
      setState(() {
        _currentPosition = freshPosition;
        _isLoadingGps = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_isSharingEnabled) {
        setState(() {
          _isSending = false;
          _isLoadingGps = false;
        });
        return;
      }
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _error = errorMsg;
        _isLoadingGps = false;
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lấy tọa độ GPS mới: $errorMsg'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final body = {
      'latitude': freshPosition.latitude,
      'longitude': freshPosition.longitude,
      'accuracyMeters': freshPosition.accuracy,
      'note': _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    };

    final res = await ApiService.post(ApiConfig.shareLocation, body: body);
    if (!mounted) return;
    setState(() => _isSending = false);

    if (res.isSuccess) {
      _noteController.clear();
      _loadHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi chia sẻ vị trí thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Không thể gửi chia sẻ vị trí.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      appBar: AppBar(title: const Text('Chia sẻ Vị trí GPS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Consent Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Đồng ý chia sẻ vị trí công tác',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isSharingEnabled,
                          onChanged: (val) {
                            setState(() {
                              _isSharingEnabled = val;
                              if (val) {
                                _fetchCurrentGps();
                              } else {
                                _currentPosition = null;
                                _error = null;
                                _isLoadingGps = false;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chức năng này giúp Quản trị viên nắm bắt vị trí công tác hiện tại của bạn. Chỉ gửi tọa độ khi bạn bật chia sẻ và ấn gửi.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isSharingEnabled) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tọa độ hiện tại',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingGps)
                        const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Đang lấy tọa độ GPS từ thiết bị...'),
                          ],
                        )
                      else if (_error != null)
                        Text(
                          'Lỗi: $_error',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        )
                      else if (_currentPosition != null) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.pin_drop,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Độ chính xác GPS: ±${_currentPosition!.accuracy.toStringAsFixed(1)}m',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú công tác (tùy chọn)',
                          hintText: 'VD: Đang khảo sát tại công trình số 2',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSending || _isLoadingGps
                            ? null
                            : _sendLocation,
                        icon: const Icon(Icons.send),
                        label: Text(
                          _isSending ? 'Đang gửi...' : 'Gửi vị trí lên Máy chủ',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // History of shared positions
            const Text(
              'Lịch sử đã gửi gần đây',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_historyError != null)
              Card(
                color: Colors.red.shade50,
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Colors.red),
                  title: Text(_historyError!),
                  trailing: TextButton(
                    onPressed: _loadHistory,
                    child: const Text('Thử lại'),
                  ),
                ),
              )
            else if (_myHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'Chưa có lịch sử chia sẻ vị trí nào.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _myHistory.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _myHistory[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.tealAccent,
                        child: Icon(Icons.location_on, color: Colors.teal),
                      ),
                      title: Text(
                        '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'Thời gian: ${_formatTime(item.sharedAtUtc)}${item.note != null ? '\n${item.note}' : ''}',
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
