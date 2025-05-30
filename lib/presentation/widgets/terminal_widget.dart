import 'package:flutter/material.dart';
import 'package:cli_util/cli_logging.dart';

class TerminalWidget extends StatefulWidget {
  final Stream<String>? dataStream;
  final bool showTimestamp;
  final int maxLines;
  final Function(String)? onCommand;

  const TerminalWidget({
    Key? key,
    this.dataStream,
    this.showTimestamp = true,
    this.maxLines = 1000,
    this.onCommand,
  }) : super(key: key);

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final List<String> _lines = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Ansi _ansi;

  @override
  void initState() {
    super.initState();
    _ansi = Ansi(Ansi.terminalSupportsAnsi);

    if (widget.dataStream != null) {
      widget.dataStream!.listen(_addLine);
    }
  }

  void _addLine(String line) {
    setState(() {
      if (widget.showTimestamp) {
        final timestamp = DateTime.now().toString().split('.').first;
        _lines.add('[$timestamp] $line');
      } else {
        _lines.add(line);
      }

      // Keep the buffer size under control
      if (_lines.length > widget.maxLines) {
        _lines.removeAt(0);
      }
    });

    // Auto scroll to bottom after adding text
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

  String _processAnsiCodes(String text) {
    // This is a simple implementation - a full ANSI parser would be more complex
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

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final command = _inputController.text.trim();
    if (command.isNotEmpty) {
      widget.onCommand?.call(command);
      _inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                      text: '${_processAnsiCodes(line)}\n',
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
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: const TextStyle(fontFamily: 'Courier New'),
                  decoration: const InputDecoration(
                    hintText: 'Enter command...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
              const SizedBox(width: 8.0),
              ElevatedButton(
                onPressed: _handleSubmit,
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}