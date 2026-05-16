import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ssh_client/data/database/app_database.dart';
import 'package:ssh_client/data/database/dao/host_dao.dart';
import 'package:ssh_client/data/database/dao/session_dao.dart';
import 'package:ssh_client/data/database/dao/message_dao.dart';
import 'package:ssh_client/data/database/dao/transfer_dao.dart';
import 'package:ssh_client/data/database/dao/quick_command_dao.dart';
import 'package:ssh_client/services/ssh/ssh_client_service.dart';
import 'package:ssh_client/services/host_identifier.dart';
import 'package:ssh_client/services/network/lan_scanner.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  final appDb = await AppDatabase.getInstance();
  return appDb.db;
});

final hostDaoProvider = FutureProvider<HostDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return HostDao(db);
});

final sessionDaoProvider = FutureProvider<SessionDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return SessionDao(db);
});

final messageDaoProvider = FutureProvider<MessageDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return MessageDao(db);
});

final transferDaoProvider = FutureProvider<TransferDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return TransferDao(db);
});

final quickCommandDaoProvider = FutureProvider<QuickCommandDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return QuickCommandDao(db);
});

final sshClientServiceProvider = Provider<SshClientService>((ref) {
  return SshClientService();
});

final hostIdentifierProvider = FutureProvider<HostIdentifier>((ref) async {
  final hostDao = await ref.watch(hostDaoProvider.future);
  return HostIdentifier(hostDao);
});

final lanScannerProvider = Provider<LanScanner>((ref) {
  return LanScanner();
});

class IsDarkModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void update(bool v) => state = v;
}

final isDarkModeProvider = NotifierProvider<IsDarkModeNotifier, bool>(IsDarkModeNotifier.new);

class DownloadDirNotifier extends Notifier<String> {
  @override
  String build() => '/storage/emulated/0/Download';
  void update(String v) => state = v;
}

final downloadDirProvider = NotifierProvider<DownloadDirNotifier, String>(DownloadDirNotifier.new);
