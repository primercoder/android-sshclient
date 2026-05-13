import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';
import 'package:ssh_client/services/ssh/ssh_client_service.dart';
import 'package:ssh_client/providers/providers.dart';

enum SshConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SshConnectionNotifier extends StateNotifier<SshConnectionState> {
  final SshClientService _service;
  String? _errorMessage;
  SshConnectionInfo? _activeConnection;

  SshConnectionNotifier(this._service) : super(SshConnectionState.disconnected);

  String? get errorMessage => _errorMessage;
  SshConnectionInfo? get activeConnection => _activeConnection;
  bool get isConnected => state == SshConnectionState.connected;

  Future<bool> connect(SshConnectionInfo info) async {
    state = SshConnectionState.connecting;
    _errorMessage = null;
    try {
      await _service.connect(info);
      _activeConnection = info;
      state = SshConnectionState.connected;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _activeConnection = null;
      state = SshConnectionState.error;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    _activeConnection = null;
    state = SshConnectionState.disconnected;
  }

  void reset() {
    _service.disconnect();
    _activeConnection = null;
    state = SshConnectionState.disconnected;
  }
}

final sshConnectionProvider =
    StateNotifierProvider<SshConnectionNotifier, SshConnectionState>((ref) {
  final service = ref.read(sshClientServiceProvider);
  return SshConnectionNotifier(service);
});
