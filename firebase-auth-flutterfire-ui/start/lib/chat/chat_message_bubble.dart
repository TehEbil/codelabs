import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatMessageBubble extends StatelessWidget {
  final String message;
  final bool isCurrentUser;
  final String type;
  final DateTime time;
  final String sender;
  final Function(String) onFileTap; // Add a parameter for the callback

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.type,
    required this.time,
    required this.sender,
    required this.onFileTap, // Initialize the callback
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    if (isCurrentUser) {
      backgroundColor = Colors.blue[100] ?? Colors.blue;
      textColor = Colors.black87;
    } else if (sender == 'AI') {
      backgroundColor = Colors.grey[200] ?? Colors.grey;
      textColor = Colors.black87;
    } else {
      backgroundColor = Colors.grey[300] ?? Colors.grey;
      textColor = Colors.black87;
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == 'text') ...[
              Text(
                message,
                style: TextStyle(color: textColor),
              ),
            ] else if (type == 'image') ...[
              Image.network(
                message,
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.red);
                },
                // headers: {'Authorization': 'Bearer YOUR_ACCESS_TOKEN'}, // Add authorization if required
              )
            ] else ...[
              InkWell(
                onTap: () => onFileTap(message), // Use the passed callback
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.black54),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Open File',
                        style: TextStyle(color: textColor),
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
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
