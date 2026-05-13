import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/ssh_connection_info.dart';
import 'package:ssh_client/services/ssh/ssh_client_service.dart';
import 'package:ssh_client/providers/providers.dart';

enum SshConnectionState {
  disconnected,
  connecting,
  authenticated,
  connected,
  error,
}

class SshConnectionNotifier extends StateNotifier<SshConnectionState> {
  final SshClientService _service;
  String? _errorMessage;

  SshConnectionNotifier(this._service) : super(SshConnectionState.disconnected);

  String? get errorMessage => _errorMessage;

  Future<void> connect(SshConnectionInfo info) async {
    state = SshConnectionState.connecting;
    _errorMessage = null;
    try {
      await _service.connect(info);
      state = SshConnectionState.connected;
    } catch (e) {
      _errorMessage = e.toString();
      state = SshConnectionState.error;
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    state = SshConnectionState.disconnected;
  }
}

final sshConnectionProvider =
    StateNotifierProvider<SshConnectionNotifier, SshConnectionState>((ref) {
  final service = ref.read(sshClientServiceProvider);
  return SshConnectionNotifier(service);
});
