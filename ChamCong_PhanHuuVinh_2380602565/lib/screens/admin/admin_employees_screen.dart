import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/load_state_view.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<EmployeeModel> _allEmployees = [];
  List<EmployeeModel> _pendingEmployees = [];
  List<DepartmentModel> _departments = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final resAll = await ApiService.get(ApiConfig.adminEmployees);
    final resPending = await ApiService.get(ApiConfig.adminPendingEmployees);
    final resDepts = await ApiService.get(ApiConfig.departments);

    if (mounted) {
      setState(() {
        if (resAll.isSuccess && resAll.data is Map<String, dynamic>) {
          final list = resAll.data['employees'] as List? ?? [];
          _allEmployees = list.map((e) => EmployeeModel.fromJson(e)).toList();
        }
        if (resPending.isSuccess && resPending.data is Map<String, dynamic>) {
          final list = resPending.data['employees'] as List? ?? [];
          _pendingEmployees = list
              .map((e) => EmployeeModel.fromJson(e))
              .toList();
        }
        if (resDepts.isSuccess && resDepts.data is List) {
          _departments = (resDepts.data as List)
              .map((d) => DepartmentModel.fromJson(d))
              .toList();
        }
        if (!resAll.isSuccess) {
          _loadError = resAll.message ?? 'Không thể tải danh sách nhân viên.';
        } else if (!resPending.isSuccess) {
          _loadError =
              resPending.message ?? 'Không thể tải tài khoản chờ duyệt.';
        } else if (!resDepts.isSuccess) {
          _loadError = resDepts.message ?? 'Không thể tải danh sách phòng ban.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActivation(EmployeeModel emp, bool activate) async {
    if (!activate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận khóa tài khoản'),
          content: Text(
            'Khóa tài khoản của ${emp.fullName}? Nhân viên sẽ không thể tiếp tục dùng phiên đăng nhập hiện tại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Khóa tài khoản'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final url = activate
        ? ApiConfig.activateEmployee(emp.employeeId)
        : ApiConfig.deactivateEmployee(emp.employeeId);
    final res = await ApiService.put(url);

    if (!mounted) return;

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activate
                ? 'Đã kích hoạt tài khoản ${emp.fullName}'
                : 'Đã vô hiệu hóa tài khoản ${emp.fullName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Thao tác thất bại'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEmployeeDetails(EmployeeModel emp) async {
    int? selectedDeptId = emp.departmentId;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(emp.fullName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Mã nhân viên:', emp.employeeCode),
                _buildInfoRow('Tên đăng nhập:', emp.userName),
                _buildInfoRow('Email:', emp.email),
                _buildInfoRow(
                  'Trạng thái:',
                  emp.isFullyActive ? 'Đang hoạt động' : 'Đã khóa / Chờ duyệt',
                ),
                const Divider(height: 24),
                const Text(
                  'Phân công Phòng ban:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: selectedDeptId,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Chưa phân phòng ban'),
                    ),
                    ..._departments.map(
                      (d) => DropdownMenuItem<int?>(
                        value: d.id,
                        child: Text(d.name),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedDeptId = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final res = await ApiService.put(
                        ApiConfig.adminEmployee(emp.employeeId),
                        body: {
                          'departmentId': selectedDeptId,
                          'clearDepartment': selectedDeptId == null,
                        },
                      );
                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cập nhật phòng ban thành công'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (ctx.mounted) setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res.message ?? 'Không thể cập nhật phòng ban.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu phòng ban'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Nhân viên'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Tất cả (${_allEmployees.length})'),
            Tab(text: 'Chờ duyệt (${_pendingEmployees.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadData)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeeList(_allEmployees, isPendingTab: false),
                _buildEmployeeList(_pendingEmployees, isPendingTab: true),
              ],
            ),
    );
  }

  Widget _buildEmployeeList(
    List<EmployeeModel> list, {
    required bool isPendingTab,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              isPendingTab
                  ? 'Không có nhân viên nào đang chờ duyệt'
                  : 'Chưa có nhân viên nào trong hệ thống',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final emp = list[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: emp.isFullyActive
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                child: Icon(
                  emp.isFullyActive ? Icons.person : Icons.person_outline,
                  color: emp.isFullyActive
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
              title: Text(
                emp.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Mã: ${emp.employeeCode} | User: ${emp.userName}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Phòng: ${emp.departmentName ?? 'Chưa phân'}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
              trailing: isPendingTab
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(80, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: () => _toggleActivation(emp, true),
                      child: const Text(
                        'Kích hoạt',
                        style: TextStyle(fontSize: 12),
                      ),
                    )
                  : PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'detail') {
                          _showEmployeeDetails(emp);
                        } else if (val == 'activate') {
                          _toggleActivation(emp, true);
                        } else if (val == 'deactivate') {
                          _toggleActivation(emp, false);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'detail',
                          child: Text('Chi tiết & Phòng ban'),
                        ),
                        if (!emp.isFullyActive)
                          const PopupMenuItem(
                            value: 'activate',
                            child: Text(
                              'Kích hoạt tài khoản',
                              style: TextStyle(color: Colors.green),
                            ),
                          )
                        else
                          const PopupMenuItem(
                            value: 'deactivate',
                            child: Text(
                              'Khóa tài khoản',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
