import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/transfer_task.dart';
import 'package:ssh_client/data/database/dao/transfer_dao.dart';
import 'package:ssh_client/providers/providers.dart';

class TransferState {
  final List<TransferTask> activeTransfers;
  final List<TransferTask> historyTransfers;

  const TransferState({
    this.activeTransfers = const [],
    this.historyTransfers = const [],
  });

  TransferState copyWith({
    List<TransferTask>? activeTransfers,
    List<TransferTask>? historyTransfers,
  }) {
    return TransferState(
      activeTransfers: activeTransfers ?? this.activeTransfers,
      historyTransfers: historyTransfers ?? this.historyTransfers,
    );
  }
}

class TransferNotifier extends StateNotifier<TransferState> {
  final Ref _ref;
  TransferDao? _dao;

  TransferNotifier(this._ref) : super(const TransferState());

  Future<TransferDao> _getDao() async {
    _dao ??= await _ref.read(transferDaoProvider.future);
    return _dao!;
  }

  Future<void> loadTransfers() async {
    final dao = await _getDao();
    final all = dao.getAllTransfers();
    final active = all.where((t) =>
      t.status == TransferStatus.pending ||
      t.status == TransferStatus.transferring
    ).toList();
    final history = all.where((t) =>
      t.status == TransferStatus.completed ||
      t.status == TransferStatus.failed ||
      t.status == TransferStatus.cancelled
    ).toList();
    state = TransferState(
      activeTransfers: active,
      historyTransfers: history,
    );
  }

  Future<void> addTransfer(TransferTask task) async {
    final dao = await _getDao();
    dao.insertTransfer(task);
    state = state.copyWith(
      activeTransfers: [...state.activeTransfers, task],
    );
  }

  Future<void> updateTransfer(TransferTask task) async {
    final dao = await _getDao();
    dao.updateTransfer(task);
    await loadTransfers();
  }
}

final transferProvider =
    StateNotifierProvider<TransferNotifier, TransferState>((ref) {
  return TransferNotifier(ref);
});
