import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat/speech_service.dart';
// import 'chat/chat_message_bubble.dart';
import 'chat/date_badge.dart';
import 'chat/firebase_service.dart';
import 'chat/file_picker_service.dart';
import 'package:intl/intl.dart';
// Import the necessary packages for Gemini
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

  // Initialize Gemini models
  late final GenerativeModel _model;
  // late final GenerativeModel _visionModel;
  late final ChatSession _chat;
  // String? _file;

  bool isListening = false;
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();

    const apiKey = 'AIzaSyAB_Dxfpf2YmxxJqZmP9m2kyFOXPOOONSo';

    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    // _visionModel = GenerativeModel(
    //   model: 'gemini-pro-vision',
    //   apiKey: apiKey,
    // );

    _chat = _model.startChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    isListeningNotifier.dispose();
    super.dispose();
  }

  Future<String> fetchGeminiResponse(String text) async {
    try {
      late final GenerateContentResponse response;
      // if (_file != null) {
      //   final firstImage = await File(_file!).readAsBytes();
      //   final prompt = TextPart(text);
      //   final imageParts = [
      //     DataPart('image/jpeg', firstImage),
      //   ];
      //   response = await _visionModel.generateContent([
      //     Content.multi([prompt, ...imageParts])
      //   ]);
      //   _file = null;
      // } else {
      var content = Content.text(text.toString());
      response = await _chat.sendMessage(content);
      // }
      return response.text ?? '';
    } catch (e) {
      print('Error fetching Gemini response: $e');
      return 'Error fetching Gemini response: $e';
    }
  }

  Future<void> _recordAndSendMessage() async {
    bool available = await _speechService.initialize();
    if (available) {
      isListeningNotifier.value = true; // Update the ValueNotifier

      String lastRecognizedText = '';

      _speechService.listen(onResult: (text) {
        if (lastRecognizedText != text) {
          lastRecognizedText = text;
          _messageController.text = text;
          _messageController.selection = TextSelection.fromPosition(
            TextPosition(offset: _messageController.text.length),
          );
        }
      });
    }
  }

  void _stopRecording() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _speechService.stop();
    if (_messageController.text.isNotEmpty) {
      _sendMessage();
    }
    _messageController.clear();
    isListeningNotifier.value = false; // Update the ValueNotifier
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: () =>
                _filePickerService.pickAndUploadFile(isPhoto: true),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () => _filePickerService.pickAndUploadFile(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isListeningNotifier,
            builder: (context, isListening, child) {
              return GestureDetector(
                onLongPressStart: (_) async {
                  if (!isListening) {
                    await _recordAndSendMessage();
                  }
                },
                onLongPressEnd: (_) {
                  if (isListening) {
                    _stopRecording();
                  }
                },
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: isListening ? Colors.red : null,
                ),
              );
            },
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

      // await Future<void>.delayed(const Duration(seconds: 1));
      // if (!mounted) return;

      // // Fetch the Gemini response
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

  void _openFile(String url) async {
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
                    final type = data['type'] ?? 'text';

                    final Timestamp? timestamp =
                        data['timestamp'] as Timestamp?;
                    final time = timestamp?.toDate() ?? DateTime.now();

                    bool showDateBadge = false;
                    if (index == 0 ||
                        (index > 0 &&
                            !_isSameDay(
                                docs[index - 1]['timestamp'], timestamp))) {
                      showDateBadge = true;
                    }

                    return Column(
                      crossAxisAlignment: isCurrentUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (showDateBadge) DateBadge(timestamp: timestamp),
                        Container(
                          padding: const EdgeInsets.only(
                              left: 14, right: 14, top: 10, bottom: 10),
                          child: Align(
                            alignment: (isCurrentUser
                                ? Alignment.topRight
                                : Alignment.topLeft),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                color: (isCurrentUser
                                    ? const Color(0xFFF69170)
                                    : Colors.white),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: type == 'image'
                                  ? Image.network(
                                      message,
                                      width: 200,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Icon(Icons.broken_image,
                                            color: Colors.red);
                                      },
                                    )
                                  : type == 'text'
                                      ? isCurrentUser
                                          ? Text(
                                              message,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: isCurrentUser
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            )
                                          : MarkdownBody(
                                              data: message,
                                              styleSheet: MarkdownStyleSheet(
                                                p: TextStyle(
                                                  fontSize: 15,
                                                  color: isCurrentUser
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            )
                                      : InkWell(
                                          onTap: () => _openFile(
                                              message), // Use the passed callback
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.insert_drive_file,
                                                  color: Colors.black54),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  'Open File',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: isCurrentUser
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 5.0),
                          child: Text(
                            DateFormat('HH:mm').format(time),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54),
                          ),
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
