import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/core/config/app_routes.dart';
import 'package:smart_net_firmware_loader/core/config/app_theme.dart';
import 'package:smart_net_firmware_loader/data/services/theme_service.dart';
import 'package:smart_net_firmware_loader/domain/blocs/home_bloc.dart';
import 'package:smart_net_firmware_loader/main.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeService = GetIt.instance<ThemeService>();
    final isDark = await themeService.isDarkMode();
    if (mounted) {
      setState(() {
        _isDarkMode = isDark;
      });
    }
  }

  Future<void> _toggleTheme() async {
    final themeService = GetIt.instance<ThemeService>();
    final newMode = !_isDarkMode;
    await themeService.setDarkMode(newMode);
    if (mounted) {
      setState(() {
        _isDarkMode = newMode;
      });

      // Update app-level theme state
      appKey.currentState?.updateTheme(newMode);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(BuildContext context) {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền đầy đủ thông tin đăng nhập'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    context.read<HomeBloc>().add(LoadInitialDataEvent());
    Navigator.pushReplacementNamed(context, AppRoutes.home);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode ? AppColors.darkBackground : AppColors.background;
    final cardColor = _isDarkMode ? AppColors.darkCardBackground : Colors.white;
    final textColor = _isDarkMode ? AppColors.darkTextPrimary : AppColors.text;
    final secondaryTextColor = _isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final inputFillColor = _isDarkMode ? AppColors.darkPanelBackground : AppColors.componentBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              color: _isDarkMode ? AppColors.warning : AppColors.primary,
            ),
            onPressed: _toggleTheme,
            tooltip: _isDarkMode ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isDarkMode ? Colors.black : AppColors.shadowColor).withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 120,
                  height: 120,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SmartNet Firmware Loader',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? AppColors.accent : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đăng nhập để tiếp tục',
                style: TextStyle(fontSize: 16, color: secondaryTextColor),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (_isDarkMode ? Colors.black : AppColors.shadowColor).withOpacity(0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Vui lòng điền đầy đủ thông tin đăng nhập',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                    TextField(
                      controller: _usernameController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Tên đăng nhập',
                        hintText: 'Nhập tên đăng nhập của bạn',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: _isDarkMode ? AppColors.accent : AppColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isDarkMode ? AppColors.darkDivider : AppColors.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isDarkMode ? AppColors.darkDivider : AppColors.borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isDarkMode ? AppColors.accent : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: inputFillColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: _usernameController.text.isNotEmpty
                              ? (_isDarkMode ? AppColors.accent : AppColors.primary)
                              : secondaryTextColor,
                        ),
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      onChanged: (_) => setState(() {}),
                      obscureText: !_showPassword,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu của bạn',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: _isDarkMode ? AppColors.accent : AppColors.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: _isDarkMode ? AppColors.accent : AppColors.primary,
                          ),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isDarkMode ? AppColors.darkDivider : AppColors.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isDarkMode ? AppColors.darkDivider : AppColors.borderColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _isDarkMode ? AppColors.accent : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: inputFillColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(
                          color: _passwordController.text.isNotEmpty
                              ? (_isDarkMode ? AppColors.accent : AppColors.primary)
                              : secondaryTextColor,
                        ),
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _login(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDarkMode ? AppColors.accent : AppColors.primary,
                          foregroundColor: _isDarkMode ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: _isDarkMode ? Colors.black : Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Đăng nhập',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Phiên bản 2.0.0',
                style: TextStyle(fontSize: 14, color: secondaryTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
