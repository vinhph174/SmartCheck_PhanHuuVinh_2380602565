import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class AdminQrScreen extends StatefulWidget {
  const AdminQrScreen({super.key});

  @override
  State<AdminQrScreen> createState() => _AdminQrScreenState();
}

class _AdminQrScreenState extends State<AdminQrScreen> {
  List<WorkLocationModel> _locations = [];
  int? _selectedLocationId;
  String _purpose = 'CheckIn'; // 'CheckIn' or 'CheckOut'
  String? _qrPayload;
  String? _locationName;
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  bool _isLoading = true;
  String? _loadError;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final res = await ApiService.get(ApiConfig.locations);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is List) {
          _locations = (res.data as List)
              .map((l) => WorkLocationModel.fromJson(l))
              .where((l) => l.isActive)
              .toList();
          if (_locations.isNotEmpty) {
            _selectedLocationId = _locations.first.id;
          }
        } else {
          _loadError = res.message ?? 'Không thể tải danh sách địa điểm.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _generateQr() async {
    if (_selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn địa điểm làm việc.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);
    final res = await ApiService.post(
      ApiConfig.qrSession,
      body: {'workLocationId': _selectedLocationId, 'purpose': _purpose},
    );
    if (!mounted) return;
    setState(() => _isGenerating = false);

    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final payload = res.data['qrPayload'] as String?;
      final locName = res.data['locationName'] as String?;
      final expiresIn = res.data['expiresInSeconds'] as int? ?? 120;

      setState(() {
        _qrPayload = payload;
        _locationName = locName;
        _remainingSeconds = expiresIn;
      });

      _startTimer();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Không thể tạo mã QR.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _qrPayload = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã QR đã hết hạn. Vui lòng bấm tạo mã mới.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo mã QR chấm công')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadLocations)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Setup Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cấu hình phiên chấm công',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Địa điểm làm việc:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedLocationId,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _locations
                                .map(
                                  (l) => DropdownMenuItem(
                                    value: l.id,
                                    child: Text(l.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedLocationId = val),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Mục đích:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(
                                    child: Text('Chấm công vào'),
                                  ),
                                  selected: _purpose == 'CheckIn',
                                  selectedColor: Colors.blue.shade100,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() => _purpose = 'CheckIn');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(
                                    child: Text('Chấm công ra'),
                                  ),
                                  selected: _purpose == 'CheckOut',
                                  selectedColor: Colors.teal.shade100,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() => _purpose = 'CheckOut');
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _generateQr,
                            icon: const Icon(Icons.qr_code),
                            label: Text(
                              _isGenerating
                                  ? 'Đang tạo...'
                                  : 'Tạo mã QR phiên mới',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QR Display Card
                  if (_qrPayload != null)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _purpose == 'CheckIn'
                                    ? Colors.blue.shade50
                                    : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_purpose == 'CheckIn' ? 'CHẤM CÔNG VÀO' : 'CHẤM CÔNG RA'} • ${_locationName ?? ''}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _purpose == 'CheckIn'
                                      ? Colors.blue.shade800
                                      : Colors.teal.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            QrImageView(
                              data: _qrPayload!,
                              version: QrVersions.auto,
                              size: 240.0,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.timer_outlined,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Mã có hiệu lực: ${_remainingSeconds}s',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _qrPayload!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã sao chép chuỗi mã QR vào bộ nhớ tạm!',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Sao chép nội dung mã QR'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chọn địa điểm và bấm "Tạo mã QR phiên mới" để xuất hiện mã quét cho nhân viên',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
