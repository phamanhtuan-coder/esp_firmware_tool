import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:smart_net_firmware_loader/core/config/app_colors.dart';
import 'package:smart_net_firmware_loader/data/services/serial_monitor_service.dart';

class LineDisplay {
  final String timestamp;
  final String content;
  bool isSystemMessage;

  LineDisplay(this.timestamp, this.content, {this.isSystemMessage = false});
}

class SerialMonitorTerminalWidget extends StatefulWidget {
  final String? initialPort;
  final int initialBaudRate;
  final bool autoStart;
  final bool isActiveTab;

  const SerialMonitorTerminalWidget({
    super.key,
    this.initialPort,
    this.initialBaudRate = 115200,
    this.autoStart = false,
    this.isActiveTab = true,
  });

  @override
  State<SerialMonitorTerminalWidget> createState() =>
      _SerialMonitorTerminalWidgetState();
}

class _SerialMonitorTerminalWidgetState
    extends State<SerialMonitorTerminalWidget> {
  final SerialMonitorService _monitorService =
      GetIt.instance<SerialMonitorService>();
  final List<String> _lines = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _subscription;
  StreamSubscription? _statusSubscription;
  bool _isMonitorActive = false;
  bool _isAutoScrollEnabled = true;
  static const maxLines = 1000;

  // Keep track of last used port and baud rate
  String? _lastPort;
  int? _lastBaudRate;

  final List<int> _baudRates = [
    300, 1200, 2400, 4800, 9600, 19200, 38400, 57600, 74880,
    115200, 230400, 250000, 500000, 921600, 1000000, 2000000
  ];
  int _selectedBaudRate = 115200;

  @override
  void initState() {
    super.initState();
    _selectedBaudRate = widget.initialBaudRate;
    _setupSerialMonitor();
  }

  void _setupSerialMonitor() {
    if (!mounted) return;

    // Setup output stream subscription
    _subscription = _monitorService.outputStream.listen(
      (data) {
        if (mounted) {
          setState(() {
            _lines.add(data);
            if (_lines.length > maxLines) {
              _lines.removeAt(0);
            }
          });

          if (_isAutoScrollEnabled) {
            _scrollToBottom();
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _lines.add('Error: $error');
            if (_lines.length > maxLines) {
              _lines.removeAt(0);
            }
          });
        }
      },
      cancelOnError: false,
    );

    // Setup status stream subscription
    _statusSubscription = _monitorService.statusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _isMonitorActive = status;
            if (status) {
              _lines.add('Serial monitor connected');
            } else {
              _lines.add('Serial monitor disconnected');
            }
            if (_lines.length > maxLines) {
              _lines.removeAt(0);
            }
          });
        }
      },
    );

    // Start monitor if conditions are met
    if (widget.isActiveTab && widget.initialPort != null) {
      _initializeMonitor();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  void _initializeMonitor() {
    if (!widget.isActiveTab || !mounted) return;

    if (widget.initialPort != null &&
        widget.initialPort!.isNotEmpty &&
        _selectedBaudRate > 0) {
      _stopMonitor();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.isActiveTab) {
          _lines.add('Starting monitor on ${widget.initialPort} at $_selectedBaudRate baud...');
          _monitorService.startMonitor(widget.initialPort!, _selectedBaudRate);
          _isMonitorActive = true;
        }
      });
    }
  }

  void _stopMonitor() {
    if (_isMonitorActive && mounted) {
      _monitorService.stopMonitor();
      _isMonitorActive = false;
      _lines.add('Serial monitor stopped');
    }
  }

  void _restartMonitor() {
    if (widget.initialPort != null &&
        widget.initialPort!.isNotEmpty &&
        mounted) {
      _stopMonitor();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.isActiveTab) {
          _monitorService.startMonitor(widget.initialPort!, _selectedBaudRate);
          _isMonitorActive = true;
          _lines.add('Restarting monitor on ${widget.initialPort} at $_selectedBaudRate baud...');
        }
      });
    }
  }

  void _sendCommand() {
    final command = _inputController.text.trim();
    if (command.isNotEmpty && mounted) {
      _monitorService.sendCommand(command);
      _inputController.clear();
    }
  }

  @override
  void didUpdateWidget(SerialMonitorTerminalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!mounted) return;

    // Handle tab changes
    if (widget.isActiveTab != oldWidget.isActiveTab) {
      if (widget.isActiveTab) {
        // Tab became active - restart monitor if there was a previous connection
        if (_lastPort != null && _lastBaudRate != null) {
          _lines.add('Tab activated - restarting monitor...');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _monitorService.startMonitor(_lastPort!, _lastBaudRate!);
              _isMonitorActive = true;
            }
          });
        } else {
          _initializeMonitor();
        }
      } else {
        // Tab became inactive - stop monitor and save current connection info
        if (_isMonitorActive && widget.initialPort != null) {
          _lastPort = widget.initialPort;
          _lastBaudRate = _selectedBaudRate;
          _lines.add('Tab deactivated - stopping monitor...');
          _stopMonitor();
        }
      }
    }
    // Handle port or baud rate changes when active
    else if (widget.isActiveTab &&
            (oldWidget.initialPort != widget.initialPort ||
             oldWidget.initialBaudRate != widget.initialBaudRate)) {
      _lastPort = widget.initialPort;
      _lastBaudRate = _selectedBaudRate;
      _lines.add('Port or baud rate changed - restarting monitor...');
      _stopMonitor();
      Future.delayed(const Duration(milliseconds: 300), _initializeMonitor);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusSubscription?.cancel();
    _stopMonitor();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkTheme ? Colors.black : AppColors.componentBackground,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SelectableText.rich(
                          TextSpan(
                            children: _lines.map((line) {
                              final _ = DateTime.now().toString().split('.')[0];
                              return TextSpan(
                                text: '$line\n',
                                style: TextStyle(
                                  color: isDarkTheme ? Colors.lightGreenAccent : const Color(0xFF2E7D32),
                                  fontFamily: 'Courier New',
                                  fontSize: 14.0,
                                  height: 1.5,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(
                            _isMonitorActive ? Icons.circle : Icons.circle_outlined,
                            color: _isMonitorActive ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _selectedBaudRate,
                            dropdownColor: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                            style: TextStyle(
                              color: isDarkTheme ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                            underline: Container(),
                            items: _baudRates.map((rate) {
                              return DropdownMenuItem<int>(
                                value: rate,
                                child: Text('$rate'),
                              );
                            }).toList(),
                            onChanged: _isMonitorActive ? null : (value) {
                              if (value != null && value != _selectedBaudRate && mounted) {
                                setState(() {
                                  _selectedBaudRate = value;
                                });
                                _restartMonitor();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: TextStyle(
                          fontFamily: 'Courier New',
                          color: isDarkTheme ? Colors.white : Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter command...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          fillColor: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                          filled: true,
                        ),
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: _isMonitorActive ? _sendCommand : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('Send'),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _isAutoScrollEnabled = !_isAutoScrollEnabled;
                          });
                        },
                        icon: Icon(
                          _isAutoScrollEnabled ? Icons.vertical_align_bottom : Icons.vertical_align_center,
                          color: _isAutoScrollEnabled ? Colors.blue : Colors.grey,
                        ),
                        tooltip: _isAutoScrollEnabled ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkTheme ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkTheme ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _lines.clear();
                          });
                        },
                        icon: const Icon(Icons.clear_all),
                        tooltip: 'Clear monitor',
                        color: isDarkTheme ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
