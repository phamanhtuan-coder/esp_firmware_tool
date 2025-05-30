import 'package:flutter/material.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:get_it/get_it.dart';
import '../../data/services/serial_monitor_service.dart';

class SerialMonitorTerminalWidget extends StatefulWidget {
  final String? initialPort;
  final int initialBaudRate;
  final bool autoStart;

  const SerialMonitorTerminalWidget({
    Key? key,
    this.initialPort,
    this.initialBaudRate = 115200,
    this.autoStart = false,
  }) : super(key: key);

  @override
  State<SerialMonitorTerminalWidget> createState() => _SerialMonitorTerminalWidgetState();
}

class _SerialMonitorTerminalWidgetState extends State<SerialMonitorTerminalWidget> {
  final SerialMonitorService _monitorService = GetIt.instance<SerialMonitorService>();
  final List<String> _lines = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Ansi _ansi;
  bool _isAutoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _ansi = Ansi(Ansi.terminalSupportsAnsi);

    _monitorService.outputStream.listen(_addLine);

    if (widget.autoStart && widget.initialPort != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _monitorService.startMonitor(widget.initialPort!, widget.initialBaudRate);
      });
    }
  }

  void _addLine(String line) {
    setState(() {
      final timestamp = DateTime.now().toString().split('.').first;
      _lines.add('[$timestamp] ${_processAnsiCodes(line)}');

      // Keep buffer size under control
      if (_lines.length > 1000) {
        _lines.removeAt(0);
      }
    });

    // Auto scroll to bottom if enabled
    if (_isAutoScrollEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _processAnsiCodes(String text) {
    // Simple ANSI code removal implementation
    return text
        .replaceAll(_ansi.bold, '')
        .replaceAll(_ansi.none, '')
        .replaceAll(_ansi.red, '')
        .replaceAll(_ansi.green, '')
        .replaceAll(_ansi.yellow, '')
        .replaceAll(_ansi.blue, '')
        .replaceAll(_ansi.magenta, '')
        .replaceAll(_ansi.cyan, '')
        .replaceAll(_ansi.gray, '');
  }

  void _sendCommand() {
    final command = _inputController.text.trim();
    if (command.isNotEmpty) {
      _monitorService.sendCommand(command);
      _inputController.clear();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Terminal output area
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.black,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SelectableText.rich(
                TextSpan(
                  children: _lines.map((line) {
                    return TextSpan(
                      text: '$line\n',
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontFamily: 'Courier New',
                        fontSize: 14.0,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        // Command input area
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
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
                    fillColor: isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade100,
                    filled: true,
                  ),
                  onSubmitted: (_) => _sendCommand(),
                ),
              ),
              const SizedBox(width: 8.0),
              IconButton(
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
              ElevatedButton(
                onPressed: _sendCommand,
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}