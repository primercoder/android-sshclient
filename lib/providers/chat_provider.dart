import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/data/models/session.dart';
import 'package:ssh_client/data/database/dao/message_dao.dart';
import 'package:ssh_client/data/database/dao/session_dao.dart';
import 'package:ssh_client/providers/providers.dart';

class ChatState {
  final List<ChatMessage> messages;
  final String currentDirectory;
  final bool isStreaming;
  final bool autoScroll;
  final String inputText;
  final Session? currentSession;

  const ChatState({
    this.messages = const [],
    this.currentDirectory = '/',
    this.isStreaming = false,
    this.autoScroll = true,
    this.inputText = '',
    this.currentSession,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? currentDirectory,
    bool? isStreaming,
    bool? autoScroll,
    String? inputText,
    Session? currentSession,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      currentDirectory: currentDirectory ?? this.currentDirectory,
      isStreaming: isStreaming ?? this.isStreaming,
      autoScroll: autoScroll ?? this.autoScroll,
      inputText: inputText ?? this.inputText,
      currentSession: currentSession ?? this.currentSession,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  MessageDao? _messageDao;
  SessionDao? _sessionDao;

  /// Active sessions keyed by sessionId
  final Map<String, Session> _activeSessions = {};

  ChatNotifier(this._ref) : super(const ChatState());

  Future<MessageDao> get _messageDaoAsync async {
    _messageDao ??= await _ref.read(messageDaoProvider.future);
    return _messageDao!;
  }

  Future<SessionDao> get _sessionDaoAsync async {
    _sessionDao ??= await _ref.read(sessionDaoProvider.future);
    return _sessionDao!;
  }

  /// Start a new session or reuse an existing active one for this host.
  /// [hostName] is the display name, [hostIp] is the IP address.
  /// Returns `true` if an existing session was reused, `false` for a brand new session.
  Future<bool> startNewSession(String hostId, {String hostName = '', String hostIp = ''}) async {
    final existing = _activeSessions.values.where((s) => s.hostId == hostId).toList();
    if (existing.isNotEmpty) {
      final session = existing.first;
      final msgDao = await _messageDaoAsync;
      final messages = msgDao.getMessagesBySession(session.sessionId);
      state = ChatState(
        messages: messages,
        currentDirectory: session.lastWorkingDir,
        currentSession: session,
      );
      return true;
    }

    final sessDao = await _sessionDaoAsync;
    final session = Session(
      sessionId: Session.generateId(hostName.isNotEmpty ? hostName : hostIp, hostIp),
      hostId: hostId,
      hostName: hostName,
      hostIp: hostIp,
      startTime: DateTime.now(),
    );
    sessDao.insertSession(session);
    _activeSessions[session.sessionId] = session;
    state = ChatState(currentSession: session);
    return false;
  }

  Future<void> loadSession(Session session) async {
    final msgDao = await _messageDaoAsync;
    final messages = msgDao.getMessagesBySession(session.sessionId);
    _activeSessions[session.sessionId] = session;
    state = ChatState(
      messages: messages,
      currentDirectory: session.lastWorkingDir,
      currentSession: session,
    );
  }

  /// End the active session for [hostId]: set endTime, persist, and remove
  /// from the active-session map so it becomes a history record.
  Future<void> endSession(String hostId) async {
    final matches = _activeSessions.values.where((s) => s.hostId == hostId).toList();
    for (final session in matches) {
      final updated = session.copyWith(endTime: DateTime.now());
      _activeSessions.remove(session.sessionId);
      try {
        final sessDao = await _sessionDaoAsync;
        sessDao.updateSession(updated);
        if (state.currentSession?.sessionId == session.sessionId) {
          state = state.copyWith(
            currentSession: updated,
            messages: const [],
            currentDirectory: '/',
          );
        }
      } catch (_) {}
    }
  }

  void clearActiveSessions() {
    _activeSessions.clear();
  }

  /// Returns true if [hostId] has any active session
  bool hasActiveSession(String hostId) {
    return _activeSessions.values.any((s) => s.hostId == hostId);
  }

  /// Returns the list of hostIds that currently have active sessions
  List<String> get activeHostIds => _activeSessions.values.map((s) => s.hostId).toSet().toList();

  Future<void> addCommand(String command) async {
    if (state.currentSession == null) return;
    final msgDao = await _messageDaoAsync;

    final msg = ChatMessage(
      messageId: Session.generateId('cmd', DateTime.now().millisecondsSinceEpoch.toString()),
      sessionId: state.currentSession!.sessionId,
      type: MessageType.command,
      content: command,
      workingDirectory: state.currentDirectory,
      timestamp: DateTime.now(),
    );
    msgDao.insertMessage(msg);
    state = state.copyWith(
      messages: [...state.messages, msg],
      inputText: '',
    );
  }

  Future<void> addOutput(String output) async {
    if (state.currentSession == null) return;
    final msgDao = await _messageDaoAsync;

    final msg = ChatMessage(
      messageId: Session.generateId('out', DateTime.now().millisecondsSinceEpoch.toString()),
      sessionId: state.currentSession!.sessionId,
      type: MessageType.output,
      content: output,
      workingDirectory: state.currentDirectory,
      timestamp: DateTime.now(),
    );
    msgDao.insertMessage(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  Future<void> addSystemMessage(String content) async {
    if (state.currentSession == null) return;
    final msgDao = await _messageDaoAsync;

    final msg = ChatMessage(
      messageId: Session.generateId('sys', DateTime.now().millisecondsSinceEpoch.toString()),
      sessionId: state.currentSession!.sessionId,
      type: MessageType.system,
      content: content,
      timestamp: DateTime.now(),
    );
    msgDao.insertMessage(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  /// Update the content of an existing message in-place (DB + state).
  Future<void> updateMessage(String messageId, String newContent) async {
    final msgDao = await _messageDaoAsync;
    msgDao.updateMessageContent(messageId, newContent);
    state = state.copyWith(
      messages: state.messages.map((m) =>
        m.messageId == messageId ? m.copyWith(content: newContent) : m,
      ).toList(),
    );
  }

  /// Add a fileTransfer-type message and return its messageId so the
  /// caller can update it later with [updateMessage].
  Future<String> addTransferMessage(String content) async {
    if (state.currentSession == null) return '';
    final msgDao = await _messageDaoAsync;
    final msgId = Session.generateId('xfer', DateTime.now().millisecondsSinceEpoch.toString());
    final msg = ChatMessage(
      messageId: msgId,
      sessionId: state.currentSession!.sessionId,
      type: MessageType.fileTransfer,
      content: content,
      timestamp: DateTime.now(),
    );
    msgDao.insertMessage(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
    return msgId;
  }

  void setInputText(String text) {
    state = state.copyWith(inputText: text);
  }

  void setDirectory(String dir) {
    final cur = state.currentSession;
    if (cur != null && _activeSessions.containsKey(cur.sessionId)) {
      final updated = cur.copyWith(lastWorkingDir: dir);
      _activeSessions[cur.sessionId] = updated;
      state = state.copyWith(currentDirectory: dir, currentSession: updated);
    } else {
      state = state.copyWith(currentDirectory: dir);
    }
  }

  void setAutoScroll(bool value) {
    state = state.copyWith(autoScroll: value);
  }

  void setStreaming(bool value) {
    state = state.copyWith(isStreaming: value);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});
