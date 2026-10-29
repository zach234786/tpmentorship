import 'package:flutter/material.dart';
// built in ui widgets
import 'package:tpmentorship/models/message.dart';
// the message data (sender, content, timestamp, etc)
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class MessageTile extends StatelessWidget {
// one row in the messages list showing a chat preview
  final Message message;
  // the message to show on this row
  final VoidCallback? onTap;
  // what to run when the row is tapped

  const MessageTile({
    super.key,
    required this.message,
    this.onTap,
  });

  String _formatTimestamp(DateTime timestamp) {
  // turns the message time into a short label depending on how old it is
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final diff = today.difference(msgDay).inDays;
    // how many days ago the message was sent

    if (diff == 0) {
      // sent today, show the time like "3:05 PM"
      final h = timestamp.hour;
      final m = timestamp.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h % 12 == 0 ? 12 : h % 12;
      // convert 24 hour time to 12 hour time
      return '$hour12:$m $period';
    } else if (diff == 1) {
      return 'Yesterday';
      // sent one day ago
    } else if (diff < 7) {
      // sent this week, show the day name
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return days[timestamp.weekday % 7];
    } else {
      return '${timestamp.day}/${timestamp.month}';
      // older than a week, show the date
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // makes the whole row tappable
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.darkCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          children: [
            // profile picture with an online dot in the corner
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.tpRed, width: 2),
                    color: AppTheme.darkBg,
                  ),
                  child: Icon(Icons.person, color: AppTheme.textSecondary, size: 24),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: message.isOnline ? Colors.green : Colors.grey,
                      // green if online, grey if offline
                      border: Border.all(color: AppTheme.darkCardBg, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // sender name and a preview of the last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // cut off long messages with "..."
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // time on the right, plus an unread count bubble if there are any
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTimestamp(message.timestamp),
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                if (message.unreadCount > 0) ...[
                  // only show the red bubble when there are unread messages
                  const SizedBox(height: 4),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.tpRed,
                    ),
                    child: Center(
                      child: Text(
                        '${message.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
