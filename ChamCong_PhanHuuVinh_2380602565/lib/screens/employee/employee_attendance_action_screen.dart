import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/attendance_position_provider.dart';
import '../../services/location_service.dart';

class EmployeeAttendanceActionScreen extends StatefulWidget {
  final ShiftAssignmentModel assignment;

  const EmployeeAttendanceActionScreen({super.key, required this.assignment});

  @override
  State<EmployeeAttendanceActionScreen> createState() =>
      _EmployeeAttendanceActionScreenState();
}

class _EmployeeAttendanceActionScreenState
    extends State<EmployeeAttendanceActionScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final AttendancePositionProvider _positionProvider =
      AttendancePositionProvider();
  Position? _currentPosition;
  double? _distanceMeters;
  bool _isLocating = true;
  bool _isSubmitting = false;
  String? _locationError;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<Position?> _fetchLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final pos = await _positionProvider.getFreshPosition();
      double? dist;
      if (widget.assignment.latitude != null &&
          widget.assignment.longitude != null) {
        dist = LocationService.calculateDistanceMeters(
          pos.latitude,
          pos.longitude,
          widget.assignment.latitude!,
          widget.assignment.longitude!,
        );
      }

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _distanceMeters = dist;
          _isLocating = false;
        });
      }
      return pos;
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString().replaceAll('Exception: ', '');
          _isLocating = false;
        });
      }
      return null;
    }
  }

  Future<void> _submitAttendance(String qrPayload) async {
    if (_isSubmitting || _hasScanned) return;
    setState(() {
      _isSubmitting = true;
      _hasScanned = true;
    });

    // Mỗi lần xác nhận phải gắn với một lần lấy GPS mới. Xóa vị trí cũ
    // trước khi gọi Geolocator để không thể gửi nhầm tọa độ cache.
    if (mounted) {
      setState(() {
        _currentPosition = null;
        _distanceMeters = null;
      });
    }
    final freshPosition = await _fetchLocation();
    if (!mounted) return;
    if (freshPosition == null) {
      setState(() {
        _isSubmitting = false;
        _hasScanned = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _locationError ??
                'Chưa lấy được tọa độ GPS mới. Vui lòng bật vị trí và thử lại.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isCheckIn = widget.assignment.status == 'Scheduled';
    final url = isCheckIn ? ApiConfig.checkIn : ApiConfig.checkOut;

    final body = {
      'shiftAssignmentId': widget.assignment.id,
      'latitude': freshPosition.latitude,
      'longitude': freshPosition.longitude,
      'accuracyMeters': freshPosition.accuracy,
      'qrPayload': qrPayload.trim(),
    };

    final res = await ApiService.post(url, body: body);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.isSuccess) {
      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : {};
      final msg = isCheckIn
          ? 'Chấm công vào thành công!'
          : 'Chấm công ra thành công!';
      final status = data['status'] == 'Late' ? 'Đi muộn' : 'Đúng giờ';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
          title: Text(msg),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trạng thái: $status',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('Ca làm: ${widget.assignment.shiftName}'),
              Text('Địa điểm: ${widget.assignment.locationName}'),
              if (_distanceMeters != null)
                Text(
                  'Khoảng cách tới điểm: ${_distanceMeters!.toStringAsFixed(1)}m',
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Hoàn tất'),
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 54),
          title: const Text('Chấm công không thành công'),
          content: Text(res.message ?? 'Mã QR hoặc vị trí không hợp lệ.'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _hasScanned = false);
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showManualInputDialog() async {
    final textController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.developer_mode, color: Colors.indigo, size: 22),
            SizedBox(width: 8),
            Text('Nhập QR Thử nghiệm', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Chỉ hiển thị ở chế độ Debug/Máy ảo khi không có camera quét thực tế. Bản phát hành chính thức chỉ dùng camera quét QR trực tiếp.',
                style: TextStyle(fontSize: 12, color: Colors.brown),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Dán chuỗi mã SC1:...',
                labelText: 'Nội dung mã QR',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final payload = textController.text.trim();
              if (payload.isNotEmpty) {
                Navigator.of(ctx).pop();
                _submitAttendance(payload);
              }
            },
            child: const Text('Gửi xác nhận'),
          ),
        ],
      ),
    );
    textController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.assignment.status == 'Scheduled';

    return Scaffold(
      appBar: AppBar(
        title: Text(isCheckIn ? 'Chấm công vào' : 'Chấm công ra'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.developer_mode),
              tooltip: 'Thử nghiệm QR trên máy ảo (Debug)',
              onPressed: _showManualInputDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // GPS Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _locationError != null
                ? Colors.red.shade50
                : (_distanceMeters != null &&
                      _distanceMeters! <=
                          (widget.assignment.allowedRadiusMeters ?? 200))
                ? Colors.green.shade50
                : Colors.amber.shade50,
            child: Row(
              children: [
                Icon(
                  _locationError != null
                      ? Icons.error_outline
                      : (_distanceMeters != null &&
                            _distanceMeters! <=
                                (widget.assignment.allowedRadiusMeters ?? 200))
                      ? Icons.check_circle_outline
                      : Icons.location_searching,
                  color: _locationError != null
                      ? Colors.red
                      : Colors.green.shade800,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isLocating
                      ? const Text('Đang lấy vị trí GPS...')
                      : _locationError != null
                      ? Text(
                          'Lỗi vị trí: $_locationError',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GPS: ${_currentPosition?.latitude.toStringAsFixed(4)}, ${_currentPosition?.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (_distanceMeters != null)
                              Text(
                                'Khoảng cách: ${_distanceMeters!.toStringAsFixed(1)}m (Bán kính cho phép: ${widget.assignment.allowedRadiusMeters ?? 200}m)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _distanceMeters! <=
                                          (widget
                                                  .assignment
                                                  .allowedRadiusMeters ??
                                              200)
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                                ),
                              ),
                          ],
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _isSubmitting ? null : _fetchLocation,
                ),
              ],
            ),
          ),

          // Camera Scanner view
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null && !_hasScanned) {
                        _submitAttendance(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // Scanner Frame Overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_isSubmitting)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Đang xác minh mã QR và GPS...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                if (kDebugMode) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showManualInputDialog,
                      icon: const Icon(Icons.edit),
                      label: const Text('Nhập hoặc dán mã QR (Debug)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const Expanded(
                    child: Text(
                      'Hướng camera vào mã QR để chấm công',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton.filled(
                  icon: const Icon(Icons.flash_on),
                  onPressed: () => _scannerController.toggleTorch(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
