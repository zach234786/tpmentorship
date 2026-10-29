class Message {
  final String id;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;

  Message({
    required this.id,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.unreadCount,
    this.isOnline = false,
  });
}
