import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../config/display_text.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/load_state_view.dart';
import '../common/login_screen.dart';
import 'admin_appeals_screen.dart';
import 'admin_assignments_screen.dart';
import 'admin_attendance_screen.dart';
import 'admin_departments_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_location_shares_screen.dart';
import 'admin_locations_screen.dart';
import 'admin_qr_screen.dart';
import 'admin_shifts_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DashboardStatsModel? _stats;
  String _adminName = '';
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
    final name = await AuthService.getFullName();
    final res = await ApiService.get(ApiConfig.adminDashboard);

    if (mounted) {
      setState(() {
        _adminName = name.isNotEmpty ? name : 'Quản trị viên';
        if (res.isSuccess && res.data is Map<String, dynamic>) {
          _stats = DashboardStatsModel.fromJson(res.data);
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
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Quản trị?',
        ),
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
        title: const Text('Trang tổng quan quản trị viên'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _logout,
          ),
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
                    // Banner quản trị viên
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.3),
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
                              Icons.admin_panel_settings,
                              size: 36,
                              color: Color(0xFF1E40AF),
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
                                  _adminName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    DisplayText.appNameTitleCase,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Thống kê
                    const Text(
                      'Thống kê tổng quan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Tổng nhân viên',
                            '${_stats?.totalEmployees ?? 0}',
                            Icons.people_outline,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Hoạt động',
                            '${_stats?.activeEmployees ?? 0}',
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Chờ kích hoạt',
                            '${_stats?.pendingEmployees ?? 0}',
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Phòng ban',
                            '${_stats?.totalDepartments ?? 0}',
                            Icons.apartment,
                            Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Ca làm việc',
                            '${_stats?.totalShifts ?? 0}',
                            Icons.schedule,
                            Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Địa điểm',
                            '${_stats?.totalLocations ?? 0}',
                            Icons.location_on_outlined,
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Danh sách chức năng
                    const Text(
                      'Chức năng Quản lý',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
                          title: 'Nhân viên & Duyệt',
                          subtitle:
                              '${_stats?.pendingEmployees ?? 0} chờ duyệt',
                          icon: Icons.people,
                          color: Colors.blue,
                          screen: const AdminEmployeesScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Tạo mã QR chấm công',
                          subtitle: 'Chấm công vào / Chấm công ra',
                          icon: Icons.qr_code_2,
                          color: Colors.teal,
                          screen: const AdminQrScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Phân công ca',
                          subtitle: 'Lập lịch nhân viên',
                          icon: Icons.event_note,
                          color: Colors.amber.shade800,
                          screen: const AdminAssignmentsScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Lịch sử chấm công',
                          subtitle: 'Xem toàn bộ dữ liệu',
                          icon: Icons.history,
                          color: Colors.indigo,
                          screen: const AdminAttendanceScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Quản lý Phòng ban',
                          subtitle:
                              '${_stats?.totalDepartments ?? 0} phòng ban',
                          icon: Icons.business,
                          color: Colors.purple,
                          screen: const AdminDepartmentsScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Quản lý Ca làm',
                          subtitle: '${_stats?.totalShifts ?? 0} ca làm việc',
                          icon: Icons.access_time_filled,
                          color: Colors.cyan.shade800,
                          screen: const AdminShiftsScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Quản lý Địa điểm',
                          subtitle:
                              '${_stats?.totalLocations ?? 0} địa điểm GPS',
                          icon: Icons.map,
                          color: Colors.green.shade700,
                          screen: const AdminLocationsScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Vị trí nhân viên',
                          subtitle: 'Theo dõi GPS chia sẻ',
                          icon: Icons.navigation,
                          color: Colors.deepOrange,
                          screen: const AdminLocationSharesScreen(),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Duyệt giải trình',
                          subtitle: 'Yêu cầu từ nhân viên',
                          icon: Icons.assignment_turned_in,
                          color: Colors.red.shade700,
                          screen: const AdminAppealsScreen(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
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
