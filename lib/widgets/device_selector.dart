import 'package:flutter/material.dart';
import '../device_service.dart';
import '../auth.dart';

class DeviceSelector extends StatefulWidget {
  final AuthService auth;
  final SpotifyDevice? selectedDevice;
  final Function(SpotifyDevice?) onDeviceSelected;

  const DeviceSelector({
    super.key,
    required this.auth,
    required this.selectedDevice,
    required this.onDeviceSelected,
  });

  @override
  State<DeviceSelector> createState() => _DeviceSelectorState();
}

class _DeviceSelectorState extends State<DeviceSelector> {
  List<SpotifyDevice>? _devices;
  bool _isLoading = false;
  String? _error;
  late DeviceService _deviceService;

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService(widget.auth);
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    if (!widget.auth.isAuthenticated) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final devices = await _deviceService.getAvailableDevices();
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isAuthenticated) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.speaker, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Afspeelapparaat',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadDevices,
                  icon: Icon(
                    Icons.refresh,
                    size: 20,
                    color: _isLoading ? Colors.grey : null,
                  ),
                  tooltip: 'Vernieuwen',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fout bij laden apparaten',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else if (_devices == null || _devices!.isEmpty)
              const Text(
                'Geen apparaten beschikbaar. Zorg ervoor dat Spotify actief is op een apparaat.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              )
            else
              Column(
                children: [
                  // "Auto" option (no specific device selected)
                  RadioListTile<SpotifyDevice?>(
                    title: const Text('Automatisch (actief apparaat)'),
                    subtitle: const Text('Speel af op het momenteel actieve apparaat'),
                    value: null,
                    groupValue: widget.selectedDevice,
                    onChanged: widget.onDeviceSelected,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 1),
                  // Available devices
                  ...(_devices!.map((device) {
                    return RadioListTile<SpotifyDevice?>(
                      title: Text(device.name),
                      subtitle: Row(
                        children: [
                          Text(device.type.toUpperCase()),
                          if (device.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ACTIEF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: device,
                      groupValue: widget.selectedDevice,
                      onChanged: widget.onDeviceSelected,
                      contentPadding: EdgeInsets.zero,
                    );
                  })),
                ],
              ),
          ],
        ),
      ),
    );
  }
}