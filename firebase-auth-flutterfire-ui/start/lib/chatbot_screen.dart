import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat/speech_service.dart';
import 'chat/chat_message_bubble.dart';
import 'chat/date_badge.dart';
import 'chat/firebase_service.dart';
import 'chat/file_picker_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

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
    }
  }

  void _stopRecording() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _speechService.stop();
    if (_messageController.text.isNotEmpty) {
      _sendMessage();
    }
    setState(() {
      _messageController.clear();
      isListening = false;
    });
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
          GestureDetector(
            onLongPress: _recordAndSendMessage,
            onLongPressUp: _stopRecording,
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening ? Colors.red : null,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
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

    final userMessage = _messageController.text;
    try {
      await _firebaseService.sendMessage(userMessage, 'text', 'User');
      _messageController.clear();
      _focusNode.requestFocus();
      _scrollToBottom();

      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      // Fetch the Gemini response
      String aiMessage = await fetchGeminiResponse(userMessage);
      await _firebaseService.sendMessage(aiMessage, 'text', 'AI');
    } catch (e) {
      if (!mounted) return;
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }

    _scrollToBottom();
  }

  Future<String> fetchGeminiResponse(String userMessage) async {
    // Simulate a delay for the API response
    await Future.delayed(const Duration(seconds: 1));
    // You can replace this with actual API call logic
    return 'Gemini response to: $userMessage';
  }

  Future<String> fetchGeminiResponseNew(String userMessage) async {
    final response = await http.post(
      Uri.parse('https://gemini-api-url.com/generate-response'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer YOUR_API_KEY',
      },
      body: jsonEncode(<String, String>{
        'message': userMessage,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response']; // Adjust based on the actual response structure
    } else {
      throw Exception('Failed to load Gemini response');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  bool _isSameDay(Timestamp? t1, Timestamp? t2) {
    if (t1 == null || t2 == null) return false;
    final d1 = t1.toDate();
    final d2 = t2.toDate();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  void _openFile(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        print('Could not launch $url');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: $url')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      print('Error launching URL: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
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
                  controller: _scrollController,
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
                          sender: data['sender'],
                          onFileTap: (url) => _openFile(context, url),
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
}
