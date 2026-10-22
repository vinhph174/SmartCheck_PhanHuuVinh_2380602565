import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/sensor_service.dart';

class EmployeeSensorsScreen extends StatefulWidget {
  const EmployeeSensorsScreen({super.key});

  @override
  State<EmployeeSensorsScreen> createState() => _EmployeeSensorsScreenState();
}

class _EmployeeSensorsScreenState extends State<EmployeeSensorsScreen> {
  final SensorService _sensorService = SensorService();
  StreamSubscription<MotionData>? _subscription;
  MotionData? _currentData;
  bool _isListening = false;
  bool _noSensorDetected = false;
  Timer? _sensorTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _stopListening(updateUi: false);
    super.dispose();
  }

  void _startListening() {
    _stopListening();
    setState(() {
      _isListening = true;
      _noSensorDetected = false;
      _currentData = null;
    });

    // If no events arrive within 3 seconds, flag that device/emulator lacks sensor
    _sensorTimeoutTimer?.cancel();
    _sensorTimeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _currentData == null) {
        setState(() => _noSensorDetected = true);
      }
    });

    try {
      _subscription = _sensorService.motionStream.listen(
        (data) {
          _sensorTimeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _currentData = data;
              _noSensorDetected = false;
            });
          }
        },
        onError: (err) {
          _sensorTimeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _noSensorDetected = true;
              _isListening = false;
            });
          }
        },
      );
    } catch (_) {
      setState(() {
        _noSensorDetected = true;
        _isListening = false;
      });
    }
  }

  void _stopListening({bool updateUi = true}) {
    _sensorTimeoutTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    if (updateUi && mounted) {
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cảm biến Chuyển động')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _isListening
                          ? (_noSensorDetected
                                ? Colors.orange.shade100
                                : Colors.green.shade100)
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.sensors,
                        size: 40,
                        color: _isListening
                            ? (_noSensorDetected
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isListening
                          ? (_noSensorDetected
                                ? 'Không phát hiện dữ liệu cảm biến'
                                : (_currentData?.status ??
                                      'Đang đọc dữ liệu...'))
                          : 'Đã tạm dừng theo dõi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _noSensorDetected
                            ? Colors.orange.shade800
                            : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _noSensorDetected
                          ? 'Thiết bị hoặc máy ảo Android hiện không hỗ trợ hoặc chưa kích hoạt cảm biến gia tốc.'
                          : 'Đọc dữ liệu X, Y, Z từ cảm biến gia tốc theo thời gian thực.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Real-time Axes Values
            if (_currentData != null && !_noSensorDetected) ...[
              const Text(
                'Thông số các trục tọa độ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAxisCard(
                      'Trục X',
                      _currentData!.x,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAxisCard(
                      'Trục Y',
                      _currentData!.y,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildAxisCard(
                      'Trục Z',
                      _currentData!.z,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Độ lớn vector gia tốc (|a|):',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${_currentData!.magnitude.toStringAsFixed(2)} m/s²',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening
                          ? Colors.grey
                          : const Color(0xFF1E40AF),
                    ),
                    onPressed: _isListening ? null : _startListening,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Bắt đầu đọc'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !_isListening ? null : _stopListening,
                    icon: const Icon(Icons.stop),
                    label: const Text('Dừng lại'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAxisCard(String title, double val, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            val.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Text(
            'm/s²',
            style: TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
