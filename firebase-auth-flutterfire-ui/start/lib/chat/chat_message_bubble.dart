import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatMessageBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final String type;
  final DateTime time;
  final Function(String) onFileTap;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.type,
    required this.time,
    required this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blueAccent : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == 'text') ...[
              Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ] else if (type == 'image') ...[
              Image.network(message),
            ] else ...[
              InkWell(
                onTap: () => onFileTap(message),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.white),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Open File',
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 5),
            Text(
              DateFormat('HH:mm').format(time),
              style: TextStyle(
                fontSize: 10,
                color: isCurrentUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
