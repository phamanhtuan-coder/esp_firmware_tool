import 'package:esp_firmware_tool/data/models/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:esp_firmware_tool/data/models/log_entry.dart';
import 'package:esp_firmware_tool/presentation/blocs/log/log_bloc.dart';
import 'package:esp_firmware_tool/utils/app_colors.dart';
import 'package:esp_firmware_tool/utils/app_config.dart';
import 'package:window_manager/window_manager.dart';
import 'package:esp_firmware_tool/data/models/batch.dart'; // Thêm model Batch

class LogView extends StatefulWidget {
  const LogView({super.key});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> with SingleTickerProviderStateMixin {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  String? _selectedBatch;
  String? _selectedDevice;
  String? _selectedFirmwareVersion;
  String? _selectedPort;
  bool _isDarkTheme = false;
  bool _isSearching = false;
  bool _localFileWarning = false;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<LogBloc>().add(LoadInitialDataEvent());
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        context.read<LogBloc>().add(AutoScrollEvent());
      }
    });
  }

  @override
  void dispose() {
    _serialController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LogBloc()..add(LoadInitialDataEvent()),
      child: BlocBuilder<LogBloc, LogState>(
        builder: (context, state) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              backgroundColor: _isDarkTheme ? Colors.grey[900] : Colors.grey[50],
              appBar: _buildHeader(),
              body: Row(
                children: [
                  Expanded(child: _buildBatchPanel(state)),
                  Expanded(child: _buildFirmwarePanel(state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: AppBar(
        backgroundColor: _isDarkTheme ? Colors.blue[800] : Colors.blue[600],
        title: const Text('Firmware Deployment Tool', style: TextStyle(color: Colors.white)),
        actions: [
          Text('${(_zoomLevel * 100).toInt()}%', style: const TextStyle(color: Colors.white)),
          IconButton(icon: const Icon(Icons.zoom_out), onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.7, 1.5))),
          IconButton(icon: const Icon(Icons.zoom_in), onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.7, 1.5))),
          IconButton(icon: const Icon(Icons.fullscreen), onPressed: () async {
            final isFullScreen = await windowManager.isFullScreen();
            await windowManager.setFullScreen(!isFullScreen);
          }),
          IconButton(icon: Icon(_isDarkTheme ? Icons.wb_sunny : Icons.nights_stay), onPressed: () => setState(() => _isDarkTheme = !_isDarkTheme)),
        ],
      ),
    );
  }

  Widget _buildBatchPanel(LogState state) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn lô (Batch)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedBatch,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fillColor: _isDarkTheme ? Colors.grey[700] : Colors.white,
                    filled: true,
                  ),
                  items: state.batches.map((batch) => DropdownMenuItem(
                    value: batch.id.toString(),
                    child: Text(batch.name),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBatch = value);
                    context.read<LogBloc>().add(SelectBatchEvent(value!));
                  },
                  hint: const Text('-- Chọn lô --'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh sách thiết bị trong lô', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _selectedBatch != null && state.devices.isNotEmpty
                        ? ListView.builder(
                      itemCount: state.devices.length,
                      itemBuilder: (context, index) {
                        final device = state.devices[index];
                        return ListTile(
                          leading: Text('${index + 1}'),
                          title: Text(device.serial),
                          subtitle: Text(
                            device.status == 'defective' ? 'Hư hỏng' : device.status == 'processing' ? 'Đang xử lý' : 'Chờ xử lý',
                            style: TextStyle(
                              color: device.status == 'defective' ? Colors.red
                                  : device.status == 'processing' ? Colors.blue
                                  : Colors.yellow,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.error, color: Colors.red),
                            onPressed: device.status == 'defective' ? null : () => _showErrorDialog(device),
                          ),
                          selected: _selectedDevice == device.id.toString(),
                          selectedTileColor: _isDarkTheme ? Colors.blue[900]!.withOpacity(0.2) : Colors.blue[50],
                          onTap: () {
                            setState(() => _selectedDevice = device.id.toString());
                            context.read<LogBloc>().add(SelectDeviceEvent(device.id.toString()));
                          },
                        );
                      },
                    )
                        : const Center(child: Text('Vui lòng chọn lô để xem danh sách thiết bị', style: TextStyle(color: Colors.grey))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmwarePanel(LogState state) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isDarkTheme ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Phiên bản Firmware', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedFirmwareVersion,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              fillColor: _isDarkTheme ? Colors.grey[700] : Colors.white,
                              filled: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'v1.0.0', child: Text('v1.0.0')),
                              DropdownMenuItem(value: 'v1.1.0', child: Text('v1.1.0')),
                              DropdownMenuItem(value: 'v2.0.0-beta', child: Text('v2.0.0-beta')),
                            ],
                            onChanged: (value) => setState(() => _selectedFirmwareVersion = value),
                            hint: const Text('-- Chọn phiên bản --'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.search, size: 16),
                      label: const Text('Find in file'),
                      style: TextButton.styleFrom(
                        backgroundColor: _isDarkTheme ? Colors.grey[700] : Colors.grey[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => setState(() => _localFileWarning = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _serialController,
                        decoration: InputDecoration(
                          labelText: 'Serial Number',
                          hintText: 'Nhập hoặc quét mã serial',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          fillColor: _isDarkTheme ? Colors.grey[700] : Colors.white,
                          filled: true,
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) context.read<LogBloc>().add(SelectSerialEvent(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Quét QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final scannedSerial = 'SN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                        _serialController.text = scannedSerial;
                        context.read<LogBloc>().add(SelectSerialEvent(scannedSerial));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cổng COM (USB)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            value: _selectedPort,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              fillColor: _isDarkTheme ? Colors.grey[700] : Colors.white,
                              filled: true,
                            ),
                            items: state.availablePorts.map((port) => DropdownMenuItem(
                              value: port,
                              child: Text(port),
                            )).toList(),
                            onChanged: (value) {
                              setState(() => _selectedPort = value);
                              context.read<LogBloc>().add(SelectUsbPortEvent(value!));
                            },
                            hint: const Text('-- Chọn cổng COM --'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(''),
                      style: TextButton.styleFrom(
                        backgroundColor: _isDarkTheme ? Colors.grey[700] : Colors.grey[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => context.read<LogBloc>().add(ScanUsbPortsEvent()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: _isDarkTheme ? Colors.grey[700] : Colors.grey[200],
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Console Log'),
                      Tab(text: 'Serial Monitor'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConsoleLog(state),
                      const Center(child: Text('No serial data to display', style: TextStyle(color: Colors.grey))),
                    ],
                  ),
                ),
                if (_isSearching) _buildSearchBar(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Log'),
                  style: TextButton.styleFrom(
                    backgroundColor: _isDarkTheme ? Colors.grey[700] : Colors.grey[200],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.read<LogBloc>().add(ClearLogsEvent()),
                ),
                ElevatedButton.icon(
                  icon: state.isFlashing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Icon(Icons.flash_on, size: 16),
                  label: Text(state.isFlashing ? 'Flashing...' : 'Flash Firmware'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isFlashing || _selectedPort == null || _selectedFirmwareVersion == null
                        ? Colors.grey
                        : Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: state.isFlashing || _selectedPort == null || _selectedFirmwareVersion == null || _selectedDevice == null
                      ? null
                      : () {
                    context.read<LogBloc>().add(InitiateFlashEvent(
                      deviceId: _selectedDevice!,
                      firmwareVersion: _selectedFirmwareVersion!,
                      deviceSerial: _serialController.text,
                      deviceType: 'esp32',
                    ));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleLog(LogState state) {
    final filteredLogs = state.filteredLogs.where((log) => log.deviceId == state.serialNumber || log.deviceId.isEmpty).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: filteredLogs.isEmpty
          ? const Center(child: Text('No logs to display', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
        controller: _scrollController,
        itemCount: filteredLogs.length,
        itemBuilder: (context, index) {
          final log = filteredLogs[index];
          return Text(
            '[${log.timestamp.toIso8601String()}] ${log.message}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: _isDarkTheme ? Colors.grey[850] : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Find in logs...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                fillColor: _isDarkTheme ? Colors.grey[700] : Colors.grey[100],
                filled: true,
              ),
              onChanged: (value) => context.read<LogBloc>().add(FilterLogEvent()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() => _isSearching = false);
              _searchController.clear();
              context.read<LogBloc>().add(FilterLogEvent());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocalFileWarning() {
    return Stack(
      children: [
        Positioned.fill(child: GestureDetector(onTap: () => setState(() => _localFileWarning = false), child: Container(color: Colors.black.withOpacity(0.5)))),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkTheme ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cảnh báo', style: TextStyle(color: _isDarkTheme ? Colors.yellow[500] : Colors.yellow[600], fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Tính năng chọn file local có thể gây ra lỗi không mong muốn. Bạn có chắc chắn muốn tiếp tục?'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => setState(() => _localFileWarning = false), child: const Text('Hủy')),
                    ElevatedButton(
                      onPressed: () => setState(() => _localFileWarning = false),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[600], foregroundColor: Colors.white),
                      child: const Text('Tiếp tục'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showErrorDialog(Device device) {
    String reason = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Báo cáo lỗi thiết bị'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Serial Number'),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.all(8), color: _isDarkTheme ? Colors.grey[700] : Colors.grey[100], child: Text(device.serial)),
            const SizedBox(height: 8),
            const Text('Lý do lỗi *'),
            const SizedBox(height: 4),
            TextField(
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nhập lý do lỗi'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            const Text('Ảnh minh chứng (tùy chọn)'),
            const SizedBox(height: 4),
            TextField(
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Chọn file ảnh'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: reason.isNotEmpty
                ? () {
              context.read<LogBloc>().add(MarkDeviceDefectiveEvent(device.id.toString(), reason: reason));
              Navigator.pop(context);
            }
                : null,
            child: const Text('Báo lỗi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}