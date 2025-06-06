import 'package:flutter/material.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';

class WarningDialog extends StatelessWidget {
  final bool isDarkTheme;
  final VoidCallback onCancel;
  final VoidCallback onContinue;
  final String title;
  final String message;
  final String type;

  const WarningDialog({
    super.key,
    required this.isDarkTheme,
    required this.onCancel,
    required this.onContinue,
    required this.title,
    required this.message,
    this.type = 'warning',
  });

  @override
  Widget build(BuildContext context) {
    Color getIconColor() {
      switch (type) {
        case 'success':
          return AppColors.success;
        case 'error':
          return AppColors.error;
        default:
          return AppColors.warning;
      }
    }

    IconData getIcon() {
      switch (type) {
        case 'success':
          return Icons.check_circle;
        case 'error':
          return Icons.error;
        default:
          return Icons.warning;
      }
    }

    // Xác định liệu dialog có nên hiển thị 2 buttons hay không
    bool shouldShowTwoButtons() {
      // Dialog warning luôn có 2 buttons
      if (type == 'warning') return true;

      // Kiểm tra title chứa các từ khóa xác nhận
      final confirmKeywords = ['xác nhận', 'hoàn thành', 'báo lỗi'];
      return confirmKeywords.any(
          (keyword) => title.toLowerCase().contains(keyword.toLowerCase()));
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0, // Bỏ shadow mặc định của Dialog
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkTheme ? AppColors.darkCardBackground : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkTheme
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon với background tròn
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getIconColor().withOpacity(isDarkTheme ? 0.15 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                getIcon(),
                color: getIconColor(),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title với màu tương phản cao
            Text(
              title,
              style: TextStyle(
                color: isDarkTheme ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Message với màu tương phản vừa phải
            Text(
              message,
              style: TextStyle(
                color: isDarkTheme
                    ? Colors.white.withOpacity(0.9)
                    : Colors.black.withOpacity(0.7),
                fontSize: 15,
                height: 1.5,
                letterSpacing: 0.15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            if (shouldShowTwoButtons()) ...[
              // Two buttons layout
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cancel button
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      side: BorderSide(
                        color: isDarkTheme
                            ? Colors.grey.withOpacity(0.5)
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Hủy',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDarkTheme
                            ? Colors.white.withOpacity(0.9)
                            : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Continue button
                  ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: getIconColor(),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      type == 'warning' ? 'Tiếp tục' : 'Xác nhận',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              // Single button for simple notifications
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getIconColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
