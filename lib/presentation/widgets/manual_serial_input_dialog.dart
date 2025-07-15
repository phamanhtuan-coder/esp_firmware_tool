import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';

class ManualSerialInputDialog extends StatefulWidget {
  final bool isDarkTheme;
  final Function(String) onDataReceived;

  const ManualSerialInputDialog({
    super.key,
    required this.isDarkTheme,
    required this.onDataReceived,
  });

  @override
  State<ManualSerialInputDialog> createState() => _ManualSerialInputDialogState();
}

class _ManualSerialInputDialogState extends State<ManualSerialInputDialog> {
  final TextEditingController _inputController = TextEditingController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _processSerialData(String data) {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      String serialNumber;

      // Kiểm tra nếu là JSON
      if (data.trim().startsWith('{')) {
        final jsonData = jsonDecode(data);

        // Kiểm tra có serial_number không
        if (jsonData['serial_number'] != null) {
          serialNumber = jsonData['serial_number'];
        } else {
          setState(() {
            _errorMessage = 'JSON không chứa trường "serial_number"';
            _isProcessing = false;
          });
          return;
        }
      } else {
        // Coi như serial number trực tiếp
        serialNumber = data.trim();
      }

      if (serialNumber.isEmpty) {
        setState(() {
          _errorMessage = 'Serial number không được để trống';
          _isProcessing = false;
        });
        return;
      }

      // Validate format serial number (có thể thêm regex validation ở đây)
      if (serialNumber.length < 5) {
        setState(() {
          _errorMessage = 'Serial number quá ngắn (tối thiểu 5 ký tự)';
          _isProcessing = false;
        });
        return;
      }

      widget.onDataReceived(serialNumber);
      Navigator.of(context).pop();

    } catch (e) {
      setState(() {
        _errorMessage = 'Định dạng dữ liệu không hợp lệ: $e';
        _isProcessing = false;
      });
    }
  }

  void _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        _inputController.text = clipboardData!.text!;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể dán từ clipboard';
      });
    }
  }

  void _clearInput() {
    _inputController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: widget.isDarkTheme
              ? AppColors.darkCardBackground
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Nhập Serial Number',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruction text
                  Text(
                    'Nhập serial number hoặc dữ liệu JSON:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: widget.isDarkTheme
                          ? AppColors.darkTextPrimary
                          : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Input field
                  TextField(
                    controller: _inputController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ:\nSERL08JUL2501JZN377PBN9JTX266R4T\n\nhoặc JSON:\n{"serial_number":"SERL08JUL..."}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: widget.isDarkTheme
                              ? AppColors.darkTextSecondary
                              : AppColors.borderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: widget.isDarkTheme
                              ? AppColors.darkTextSecondary
                              : AppColors.borderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: widget.isDarkTheme
                          ? AppColors.darkPanelBackground
                          : Colors.grey[50],
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isDarkTheme
                          ? AppColors.darkTextPrimary
                          : AppColors.text,
                    ),
                    onChanged: (value) {
                      if (_errorMessage != null) {
                        setState(() {
                          _errorMessage = null;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Action buttons row
                  Row(
                    children: [
                      // Paste button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Dán'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                            side: const BorderSide(color: AppColors.secondary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Clear button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearInput,
                          icon: const Icon(Icons.clear),
                          label: const Text('Xóa'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () {
                              _processSerialData(_inputController.text);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Đang xử lý...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Xác nhận',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
