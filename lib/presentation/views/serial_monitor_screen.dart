import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:get_it/get_it.dart';

import '../../data/services/serial_monitor_service.dart';
import '../widgets/terminal_widget.dart';

class SerialMonitorScreen extends StatefulWidget {
  const SerialMonitorScreen({Key? key}) : super(key: key);

  @override
  State<SerialMonitorScreen> createState() => _SerialMonitorScreenState();
}

class _SerialMonitorScreenState extends State<SerialMonitorScreen> {
  final SerialMonitorService _monitorService = GetIt.instance<SerialMonitorService>();
  List<String> _availablePorts = [];
  String? _selectedPort;
  int _selectedBaudRate = 115200;
  final List<int> _baudRates = [9600, 19200, 38400, 57600, 115200];
  bool _isMonitorRunning = false;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
  }

  void _refreshPorts() {
    setState(() {
      _availablePorts = SerialPort.availablePorts;
      if (_availablePorts.isNotEmpty && _selectedPort == null) {
        _selectedPort = _availablePorts.first;
      } else if (!_availablePorts.contains(_selectedPort)) {
        _selectedPort = _availablePorts.isNotEmpty ? _availablePorts.first : null;
      }
    });
  }

  void _toggleMonitor() async {
    if (_selectedPort == null) {
      _showSnackBar('No port selected');
      return;
    }

    setState(() {
      _isMonitorRunning = !_isMonitorRunning;
    });

    if (_isMonitorRunning) {
      await _monitorService.startMonitor(_selectedPort!, _selectedBaudRate);
    } else {
      await _monitorService.stopMonitor();
    }
  }

  void _showSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _sendCommand(String command) {
    _monitorService.sendCommand(command);
  }

  @override
  void dispose() {
    _monitorService.stopMonitor();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPorts,
            tooltip: 'Refresh ports',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Port dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedPort,
                    onChanged: _isMonitorRunning
                        ? null
                        : (newValue) {
                            setState(() {
                              _selectedPort = newValue;
                            });
                          },
                    items: _availablePorts
                        .map<DropdownMenuItem<String>>((String port) {
                      return DropdownMenuItem<String>(
                        value: port,
                        child: Text(port),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8.0),
                // Baud rate dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Baud Rate',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedBaudRate,
                    onChanged: _isMonitorRunning
                        ? null
                        : (newValue) {
                            setState(() {
                              _selectedBaudRate = newValue!;
                            });
                          },
                    items: _baudRates.map<DropdownMenuItem<int>>((int rate) {
                      return DropdownMenuItem<int>(
                        value: rate,
                        child: Text('$rate'),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8.0),
                // Start/Stop button
                ElevatedButton.icon(
                  onPressed: _toggleMonitor,
                  icon: Icon(_isMonitorRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(_isMonitorRunning ? 'Stop' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isMonitorRunning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: TerminalWidget(
              dataStream: _monitorService.outputStream,
              onCommand: _sendCommand,
            ),
          ),
        ],
      ),
    );
  }
}