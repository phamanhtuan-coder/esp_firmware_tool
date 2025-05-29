import 'package:flutter/material.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/app_routes.dart';
import 'package:esp_firmware_tool/presentation/widgets/rounded_button.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) async {
    setState(() => _isLoading = true);
    // Simulate API login (replace with actual API call)
    await Future.delayed(const Duration(seconds: 1));
    if (_usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      Navigator.pushReplacementNamed(context, AppRoutes.logs);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid credentials'), backgroundColor: AppColors.error),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Technician Login', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 24),
              RoundedButton(
                label: 'Login',
                color: AppColors.primary,
                isLoading: _isLoading,
                onPressed: () => _login(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}