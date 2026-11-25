class InboxNotification {
  const InboxNotification({
    required this.id, required this.title, required this.message,
    required this.type, required this.isRead, required this.sentAt,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String sentAt;

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || !RegExp(r'^[1-9][0-9]*$').hasMatch(id) ||
        json['title'] is! String || json['message'] is! String ||
        json['notification_type'] is! String || json['is_read'] is! bool ||
        json['sent_at'] is! String) {
      throw const FormatException('Invalid notification');
    }
    return InboxNotification(id: id, title: json['title'] as String,
      message: json['message'] as String, type: json['notification_type'] as String,
      isRead: json['is_read'] as bool, sentAt: json['sent_at'] as String);
  }

  InboxNotification read() => InboxNotification(id: id, title: title,
    message: message, type: type, isRead: true, sentAt: sentAt);
}

class InboxPageResult {
  const InboxPageResult(this.items, this.unreadCount, this.nextBeforeId);
  final List<InboxNotification> items;
  final int unreadCount;
  final String? nextBeforeId;

  static int parseUnread(Map<String, dynamic> json) {
    final n = json['unread_count'];
    if (n is! int || n < 0) throw const FormatException('Invalid unread count');
    return n;
  }

  factory InboxPageResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final cursor = json['next_before_id'];
    if (data is! List || (cursor != null &&
        (cursor is! String || !RegExp(r'^[1-9][0-9]*$').hasMatch(cursor)))) {
      throw const FormatException('Invalid inbox page');
    }
    final items = data.map((item) => InboxNotification.fromJson(
      Map<String, dynamic>.from(item as Map))).toList(growable: false);
    return InboxPageResult(items, parseUnread(json), cursor as String?);
  }
}
