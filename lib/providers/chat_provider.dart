import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ssh_client/data/models/chat_message.dart';
import 'package:ssh_client/data/models/session.dart';
import 'package:ssh_client/data/database/dao/message_dao.dart';
import 'package:ssh_client/data/database/dao/session_dao.dart';
import 'package:ssh_client/providers/providers.dart';
import 'package:uuid/uuid.dart';

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
  static const _uuid = Uuid();

  /// Track active sessions per hostId so re-entering reuses the same one
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

  Future<void> loadSession(Session session) async {
    final msgDao = await _messageDaoAsync;
    final messages = msgDao.getMessagesBySession(session.sessionId);
    _activeSessions[session.hostId] = session;
    state = ChatState(
      messages: messages,
      currentDirectory: session.lastWorkingDir,
      currentSession: session,
    );
  }

  Future<void> startNewSession(String hostId) async {
    // Reuse active session if exists (keep-session flow)
    if (_activeSessions.containsKey(hostId)) {
      final session = _activeSessions[hostId]!;
      final msgDao = await _messageDaoAsync;
      final messages = msgDao.getMessagesBySession(session.sessionId);
      state = ChatState(
        messages: messages,
        currentDirectory: session.lastWorkingDir,
        currentSession: session,
      );
      return;
    }

    final sessDao = await _sessionDaoAsync;
    final session = Session(
      sessionId: _uuid.v4(),
      hostId: hostId,
      startTime: DateTime.now(),
    );
    sessDao.insertSession(session);
    _activeSessions[hostId] = session;
    state = ChatState(currentSession: session);
  }

  /// Called when user explicitly disconnects the SSH session
  void endSession(String hostId) {
    _activeSessions.remove(hostId);
  }

  void clearActiveSessions() {
    _activeSessions.clear();
  }

  Future<void> addCommand(String command) async {
    if (state.currentSession == null) return;
    final msgDao = await _messageDaoAsync;

    final msg = ChatMessage(
      messageId: _uuid.v4(),
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
      messageId: _uuid.v4(),
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
      messageId: _uuid.v4(),
      sessionId: state.currentSession!.sessionId,
      type: MessageType.system,
      content: content,
      timestamp: DateTime.now(),
    );
    msgDao.insertMessage(msg);
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void setInputText(String text) {
    state = state.copyWith(inputText: text);
  }

  void setDirectory(String dir) {
    state = state.copyWith(currentDirectory: dir);
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
