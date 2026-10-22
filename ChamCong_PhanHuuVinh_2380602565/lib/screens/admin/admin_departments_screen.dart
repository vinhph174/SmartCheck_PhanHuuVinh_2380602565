import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/form_validators.dart';
import '../../widgets/load_state_view.dart';

class AdminDepartmentsScreen extends StatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  State<AdminDepartmentsScreen> createState() => _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen> {
  List<DepartmentModel> _departments = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final res = await ApiService.get(ApiConfig.departments);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is List) {
          _departments = (res.data as List)
              .map((d) => DepartmentModel.fromJson(d))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải danh sách phòng ban.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEditDialog({DepartmentModel? department}) async {
    final nameController = TextEditingController(text: department?.name ?? '');
    final descController = TextEditingController(
      text: department?.description ?? '',
    );
    bool isActive = department?.isActive ?? true;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(
            department == null ? 'Thêm Phòng ban mới' : 'Chỉnh sửa Phòng ban',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên phòng ban *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Mô tả phòng ban'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Đang hoạt động'),
                value: isActive,
                onChanged: (val) => setDialogState(() => isActive = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final validationError = FormValidators.departmentName(
                        name,
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

                      setDialogState(() => isSaving = true);

                      final body = {
                        'name': name,
                        'description': descController.text.trim(),
                        'isActive': isActive,
                      };

                      final res = department == null
                          ? await ApiService.post(
                              ApiConfig.departments,
                              body: body,
                            )
                          : await ApiService.put(
                              ApiConfig.department(department.id),
                              body: body,
                            );

                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadDepartments();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                department == null
                                    ? 'Thêm phòng ban thành công'
                                    : 'Cập nhật thành công',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (ctx.mounted) setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res.message ?? 'Thao tác thất bại'),
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
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descController.dispose();
  }

  Future<void> _deleteDepartment(DepartmentModel dept) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa phòng ban "${dept.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.delete(ApiConfig.department(dept.id));
      if (!mounted) return;
      if (res.isSuccess) {
        _loadDepartments();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa phòng ban thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message ??
                  'Không thể xóa phòng ban đang có dữ liệu liên kết.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Phòng ban')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? LoadErrorView(message: _loadError!, onRetry: _loadDepartments)
          : _departments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có phòng ban nào'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDepartments,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _departments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final dept = _departments[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: dept.isActive
                            ? Colors.purple.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.business,
                          color: dept.isActive ? Colors.purple : Colors.grey,
                        ),
                      ),
                      title: Text(
                        dept.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        dept.description?.isNotEmpty == true
                            ? dept.description!
                            : 'Không có mô tả',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () =>
                                _showAddEditDialog(department: dept),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteDepartment(dept),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Thêm phòng ban',
        child: const Icon(Icons.add),
      ),
    );
  }
}
