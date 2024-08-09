import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat/speech_service.dart';
import 'chat/chat_message_bubble.dart';
import 'chat/date_badge.dart';
import 'chat/firebase_service.dart';
import 'chat/file_picker_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ChatbotScreenState createState() => ChatbotScreenState();
}

class ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SpeechService _speechService = SpeechService();
  final FirebaseService _firebaseService = FirebaseService();
  final FilePickerService _filePickerService = FilePickerService();
  bool isListening = false;

  Future<void> _recordAndSendMessage() async {
    bool available = await _speechService.initialize();
    if (available) {
      setState(() {
        isListening = true;
      });
      _speechService.listen(onResult: (text) {
        setState(() {
          _messageController.text = text;
        });
      });
      await Future.delayed(const Duration(milliseconds: 200)); // Delay before stopping
      _speechService.stop();
      _sendMessage();
      _messageController.clear();
      setState(() {
        isListening = false;
      });
    }
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: () => _filePickerService.pickAndUploadFile(isPhoto: true),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () => _filePickerService.pickAndUploadFile(),
          ),
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _recordAndSendMessage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Enter your message',
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    try {
      await _firebaseService.sendMessage(_messageController.text, 'text');
      _messageController.clear();

      await Future<void>.delayed(const Duration(seconds: 1));
      await _firebaseService.sendMessage(
          'This is an AI response to: ${_messageController.text}', 'text');
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.chatCollection
                  .where('userId', isEqualTo: _firebaseService.currentUser)
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                List<DocumentSnapshot> docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final message = data['message'] ?? 'No message';
                    final sender = data['sender'] ?? 'Unknown sender';
                    final isCurrentUser = sender == 'User';

                    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    final time = timestamp?.toDate() ?? DateTime.now();

                    bool showDateBadge = false;
                    if (index == 0 ||
                        (index > 0 && !_isSameDay(docs[index - 1]['timestamp'], timestamp))) {
                      showDateBadge = true;
                    }

                    return Column(
                      crossAxisAlignment: isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (showDateBadge) DateBadge(timestamp: timestamp),
                        ChatMessageBubble(
                          message: message,
                          isCurrentUser: isCurrentUser,
                          type: data['type'],
                          time: time,
                          onFileTap: _openFile,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  bool _isSameDay(Timestamp? t1, Timestamp? t2) {
    if (t1 == null || t2 == null) return false;
    final d1 = t1.toDate();
    final d2 = t2.toDate();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  void _openFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }
}
