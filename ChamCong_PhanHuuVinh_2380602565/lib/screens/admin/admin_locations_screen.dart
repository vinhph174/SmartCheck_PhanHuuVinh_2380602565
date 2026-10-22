import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../utils/form_validators.dart';
import '../../widgets/load_state_view.dart';

class AdminLocationsScreen extends StatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  State<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends State<AdminLocationsScreen> {
  List<WorkLocationModel> _locations = [];
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
    final res = await ApiService.get(ApiConfig.locations);
    if (mounted) {
      setState(() {
        if (res.isSuccess && res.data is List) {
          _locations = (res.data as List)
              .map((l) => WorkLocationModel.fromJson(l))
              .toList();
        } else {
          _loadError = res.message ?? 'Không thể tải danh sách địa điểm.';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEditDialog({WorkLocationModel? location}) async {
    final nameController = TextEditingController(text: location?.name ?? '');
    final addrController = TextEditingController(text: location?.address ?? '');
    final latController = TextEditingController(
      text: '${location?.latitude ?? 10.7769}',
    );
    final lngController = TextEditingController(
      text: '${location?.longitude ?? 106.7009}',
    );
    final radiusController = TextEditingController(
      text: '${location?.allowedRadiusMeters ?? 200}',
    );
    bool isActive = location?.isActive ?? true;
    bool gettingGps = false;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(
            location == null
                ? 'Thêm Địa điểm làm việc'
                : 'Sửa Địa điểm làm việc',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên địa điểm * (VD: Trụ sở chính)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addrController,
                  decoration: const InputDecoration(labelText: 'Địa chỉ *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Vĩ độ (Lat) *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Kinh độ (Lng) *',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: gettingGps
                      ? null
                      : () async {
                          setDialogState(() => gettingGps = true);
                          try {
                            final pos =
                                await LocationService.getCurrentPosition();
                            latController.text = pos.latitude.toStringAsFixed(
                              6,
                            );
                            lngController.text = pos.longitude.toStringAsFixed(
                              6,
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Không thể lấy GPS: ${e.toString().replaceAll('Exception: ', '')}',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } finally {
                            if (ctx.mounted) {
                              setDialogState(() => gettingGps = false);
                            }
                          }
                        },
                  icon: gettingGps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Lấy tọa độ vị trí hiện tại'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: radiusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bán kính chấm công (mét)',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang kích hoạt'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: gettingGps || isSaving
                  ? null
                  : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: gettingGps || isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final addr = addrController.text.trim();
                      final validationError = FormValidators.location(
                        name: name,
                        address: addr,
                        latitude: latController.text,
                        longitude: lngController.text,
                        radiusMeters: radiusController.text,
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
                      final lat = FormValidators.parseDecimal(
                        latController.text,
                      )!;
                      final lng = FormValidators.parseDecimal(
                        lngController.text,
                      )!;
                      final radius = int.parse(radiusController.text.trim());
                      setDialogState(() => isSaving = true);

                      final body = {
                        'name': name,
                        'address': addr,
                        'latitude': lat,
                        'longitude': lng,
                        'allowedRadiusMeters': radius,
                        'isActive': isActive,
                      };

                      final res = location == null
                          ? await ApiService.post(
                              ApiConfig.locations,
                              body: body,
                            )
                          : await ApiService.put(
                              ApiConfig.location(location.id),
                              body: body,
                            );

                      if (res.isSuccess) {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        _loadLocations();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                location == null
                                    ? 'Thêm địa điểm thành công'
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
    addrController.dispose();
    latController.dispose();
    lngController.dispose();
    radiusController.dispose();
  }

  Future<void> _deleteLocation(WorkLocationModel loc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa địa điểm "${loc.name}"?'),
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
      final res = await ApiService.delete(ApiConfig.location(loc.id));
      if (!mounted) return;
      if (res.isSuccess) {
        _loadLocations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xóa địa điểm thành công'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message ?? 'Không thể xóa địa điểm đang có lịch phân công.',
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
      appBar: AppBar(title: const Text('Quản lý Địa điểm GPS')),
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
                    Icons.location_on_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có địa điểm làm việc nào'),
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
                  final loc = _locations[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: loc.isActive
                            ? Colors.teal.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.location_on,
                          color: loc.isActive ? Colors.teal : Colors.grey,
                        ),
                      ),
                      title: Text(
                        loc.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${loc.address}\nGPS: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)} (Bán kính: ${loc.allowedRadiusMeters}m)',
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showAddEditDialog(location: loc),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteLocation(loc),
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
        tooltip: 'Thêm địa điểm',
        child: const Icon(Icons.add),
      ),
    );
  }
}
