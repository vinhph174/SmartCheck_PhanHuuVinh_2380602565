import 'package:flutter/material.dart';

import '../../config/display_text.dart';

import '../../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _userNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _userNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final res = await AuthService.register(
      fullName: _fullNameController.text,
      userName: _userNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đăng ký thành công! Vui lòng kiểm tra email để nhận mã OTP.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              VerifyEmailScreen(email: _emailController.text.trim()),
        ),
      );
    } else {
      final msg = res.message ?? 'Đăng ký không thành công.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      final isAccountCreated =
          res.data is Map && res.data['accountCreated'] == true;
      if (isAccountCreated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                VerifyEmailScreen(email: _emailController.text.trim()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký nhân viên')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Tạo tài khoản ${DisplayText.appNameTitleCase}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Đăng ký tài khoản nhân viên để tham gia chấm công',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Họ và tên',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: Nguyễn Văn An',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập họ và tên'
                      : null,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tên đăng nhập',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _userNameController,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: nguyenvana',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Vui lòng nhập tên đăng nhập'
                      : null,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Email nhận OTP',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'email@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Email không đúng định dạng';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Mật khẩu',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Ít nhất 8 ký tự, gồm chữ hoa, thường & số',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (v.length < 8) {
                      return 'Mật khẩu phải từ 8 ký tự trở lên';
                    }
                    if (!v.contains(RegExp(r'[A-Z]'))) {
                      return 'Mật khẩu cần ít nhất 1 chữ hoa';
                    }
                    if (!v.contains(RegExp(r'[a-z]'))) {
                      return 'Mật khẩu cần ít nhất 1 chữ thường';
                    }
                    if (!v.contains(RegExp(r'[0-9]'))) {
                      return 'Mật khẩu cần ít nhất 1 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
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
                      : const Text('Đăng ký tài khoản'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản? '),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: Color(0xFF1E40AF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
