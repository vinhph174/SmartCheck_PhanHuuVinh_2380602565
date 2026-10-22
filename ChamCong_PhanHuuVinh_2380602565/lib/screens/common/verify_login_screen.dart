import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../employee/employee_dashboard_screen.dart';

class VerifyLoginScreen extends StatefulWidget {
  final String userName;
  final String loginTicket;

  const VerifyLoginScreen({
    super.key,
    required this.userName,
    required this.loginTicket,
  });

  @override
  State<VerifyLoginScreen> createState() => _VerifyLoginScreenState();
}

class _VerifyLoginScreenState extends State<VerifyLoginScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã OTP bao gồm đúng 6 chữ số.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final res = await AuthService.verifyLogin(
      widget.userName,
      widget.loginTicket,
      code,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess) {
      final role = await AuthService.getRole();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xác minh OTP thành công! Đang vào hệ thống...'),
          backgroundColor: Colors.green,
        ),
      );

      if (role == 'Admin') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmployeeDashboardScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'OTP không chính xác hoặc đã hết hạn.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác minh 2 bước OTP')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Nhập mã OTP',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Mã xác minh gồm 6 số đã được gửi đến email đăng ký của tài khoản "${widget.userName}". Có hiệu lực trong 5 phút.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  prefixIcon: Icon(Icons.security),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleVerify,
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Xác nhận & Vào ứng dụng'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Quay lại màn hình đăng nhập'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
