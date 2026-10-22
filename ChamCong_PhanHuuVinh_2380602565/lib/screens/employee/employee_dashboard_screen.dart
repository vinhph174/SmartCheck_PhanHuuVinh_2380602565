import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../config/display_text.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/load_state_view.dart';
import '../common/login_screen.dart';
import 'employee_appeals_screen.dart';
import 'employee_attendance_action_screen.dart';
import 'employee_attendance_history_screen.dart';
import 'employee_location_share_screen.dart';
import 'employee_schedule_screen.dart';
import 'employee_sensors_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  String _fullName = '';
  String _userName = '';
  List<ShiftAssignmentModel> _myAssignments = [];
  ShiftAssignmentModel? _todayAssignment;
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
    final fn = await AuthService.getFullName();
    final un = await AuthService.getUserName();

    final res = await ApiService.get(ApiConfig.myAssignments);

    if (mounted) {
      setState(() {
        _fullName = fn.isNotEmpty ? fn : 'Nhân viên';
        _userName = un;
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          final list = res.data['assignments'] as List? ?? [];
          _myAssignments = list
              .map((a) => ShiftAssignmentModel.fromJson(a))
              .toList();

          final now = DateTime.now();
          final todayStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          try {
            _todayAssignment = _myAssignments.firstWhere(
              (a) => a.workDate == todayStr,
            );
          } catch (_) {
            _todayAssignment = null;
          }
        } else {
          _loadError = res.message ?? 'Không thể tải dữ liệu tổng quan.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang tổng quan nhân viên'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadData)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin nhân viên
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 36,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Xin chào,',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  _fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tài khoản: $_userName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ca làm hôm nay
                    const Text(
                      'Ca làm hôm nay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_todayAssignment != null)
                      Card(
                        elevation: 3,
                        color: Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
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
                                    _todayAssignment!.shiftName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _todayAssignment!.status ==
                                              'Completed'
                                          ? Colors.green.shade100
                                          : _todayAssignment!.status ==
                                                'InProgress'
                                          ? Colors.orange.shade100
                                          : Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      DisplayText.shiftStatus(
                                        _todayAssignment!.status,
                                      ),
                                      style: TextStyle(
                                        color:
                                            _todayAssignment!.status ==
                                                'Completed'
                                            ? Colors.green.shade800
                                            : _todayAssignment!.status ==
                                                  'InProgress'
                                            ? Colors.orange.shade800
                                            : Colors.blue.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Thời gian: ${_todayAssignment!.startTime} - ${_todayAssignment!.endTime}',
                              ),
                              Text(
                                'Địa điểm: ${_todayAssignment!.locationName}',
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EmployeeAttendanceActionScreen(
                                                assignment: _todayAssignment!,
                                              ),
                                        ),
                                      )
                                      .then((_) => _loadData());
                                },
                                icon: const Icon(Icons.qr_code_scanner),
                                label: Text(
                                  _todayAssignment!.status == 'InProgress'
                                      ? 'Chấm công ra'
                                      : 'Chấm công vào',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_available,
                                color: Colors.grey.shade400,
                                size: 36,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Hôm nay bạn không có lịch phân ca làm việc.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Grid Menu
                    const Text(
                      'Chức năng chính',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMenuCard(
                          context,
                          title: 'Quét mã QR chấm công',
                          subtitle: 'Camera kết hợp vị trí GPS',
                          icon: Icons.qr_code_scanner,
                          color: Colors.blue,
                          screen: _todayAssignment != null
                              ? EmployeeAttendanceActionScreen(
                                  assignment: _todayAssignment!,
                                )
                              : const EmployeeScheduleScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Lịch làm việc',
                          subtitle: '${_myAssignments.length} ca đã phân',
                          icon: Icons.calendar_month,
                          color: Colors.indigo,
                          screen: const EmployeeScheduleScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Lịch sử chấm công',
                          subtitle: 'Xem giờ vào / ra',
                          icon: Icons.history,
                          color: Colors.teal,
                          screen: const EmployeeAttendanceHistoryScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Chia sẻ vị trí GPS',
                          subtitle: 'Bật/tắt theo dõi GPS',
                          icon: Icons.share_location,
                          color: Colors.deepOrange,
                          screen: const EmployeeLocationShareScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Cảm biến chuyển động',
                          subtitle: 'Cảm biến gia tốc X/Y/Z',
                          icon: Icons.sensors,
                          color: Colors.purple,
                          screen: const EmployeeSensorsScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Giải trình chấm công',
                          subtitle: 'Gửi & theo dõi đơn',
                          icon: Icons.edit_note,
                          color: Colors.amber.shade800,
                          screen: const EmployeeAppealsScreen(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => screen))
              .then((_) => _loadData()),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              radius: 22,
              child: Icon(icon, color: color, size: 24),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
