import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat/speech_service.dart';
import 'chat/date_badge.dart';
import 'chat/firebase_service.dart';
import 'chat/file_picker_service.dart';
import 'package:intl/intl.dart'; // Make sure this is imported
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatbotScreen extends StatefulWidget {
  final String? chatId; // Add chatId parameter for existing chat

  const ChatbotScreen({super.key, this.chatId}); // Update constructor

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

  late final GenerativeModel _model;
  late final ChatSession _chat;

  bool isListening = false;
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  late Future<String> chatIdFuture;

  @override
  void initState() {
    super.initState();

    const apiKey = 'AIzaSyAB_Dxfpf2YmxxJqZmP9m2kyFOXPOOONSo';

    const systemInstruction =
        'Du bist ein einfühlsamer und verständnisvoller Chatbot, der als erfahrener Psychologe und Therapeut agiert. Deine Aufgabe ist es, den Nutzern bei einer Vielzahl von persönlichen und emotionalen Herausforderungen zu helfen. Deine Antworten sollten stets respektvoll, unterstützend und informativ sein. Dein Ziel ist es, den Nutzern zu helfen, ihre Gedanken und Gefühle besser zu verstehen und mögliche Lösungsansätze oder Bewältigungsstrategien aufzuzeigen. Du solltest auf folgende Themen eingehen können:\n\n1) Depressionen: Biete Unterstützung und Informationen zu Symptomen, Bewältigungsstrategien und Ermutigung, professionelle Hilfe in Anspruch zu nehmen.\n\n2) Selbstmordgedanken: Reagiere sofort mit Mitgefühl und Dringlichkeit, und ermutige den Nutzer, sich an Notdienste oder Fachkräfte zu wenden. Betone, dass Hilfe verfügbar ist.\n\n3) Sexuelle Orientierung und Identität (homo- oder bisexuelle Probleme, Transgender): Sei respektvoll und unterstützend, fördere Akzeptanz und Selbstannahme und biete Informationen über relevante Ressourcen und Gemeinschaften.\n\n4) Sexueller Missbrauch: Handle mit äußerster Sensibilität, biete Informationen über Unterstützungsangebote und ermutige die betroffene Person, sich an Fachleute oder Hilfsorganisationen zu wenden.\n\n5) Beziehungsprobleme (Ehe, Paarbeziehungen, Freundschaften): Biete Ratschläge zu Kommunikation, Konfliktlösung und Beziehungsstärkung, und fördere das Verständnis für die Perspektiven aller Beteiligten.\n\nAchte darauf, stets die Grenzen deiner Rolle als Chatbot zu erkennen und ermutige die Nutzer, professionelle Hilfe in Anspruch zu nehmen, wenn es nötig ist. Sei eine Quelle des Mitgefühls und der Unterstützung, und respektiere die Privatsphäre und Vertraulichkeit der Nutzer.';

    _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        systemInstruction: Content.system(systemInstruction),
        apiKey: apiKey,
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none)
        ]);

    chatIdFuture = _initializeChat();
  }

  Future<String> _initializeChat() async {
    try {
      String chatId;

      if (widget.chatId != null) {
        // Use the existing chat ID
        chatId = widget.chatId!;
      } else {
        // Create a new chat and get its ID with title based on first message
        DocumentReference newChat = await _firebaseService
            .createNewChatWithTitle('Start a new conversation...');
        chatId = newChat.id;
      }

      // Load chat history for the existing chat
      QuerySnapshot messagesSnapshot = await _firebaseService.chatCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      List<Content> history = [];
      for (var messageDoc in messagesSnapshot.docs) {
        var messageData = messageDoc.data() as Map<String, dynamic>;
        history.add(Content.text(messageData['message'] ?? ''));
      }

      // Start a new chat session with or without history
      _chat = _model.startChat(history: history);

      return chatId;
    } catch (e) {
      print('Error initializing chat: $e');
      rethrow;
    }
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
      var content = Content.text(text.toString());
      response = await _chat.sendMessage(content);
      return response.text ?? '';
    } catch (e) {
      print('Error fetching Gemini response: $e');
      return 'Error fetching Gemini response: $e';
    }
  }

  Future<void> _recordAndSendMessage() async {
    bool available = await _speechService.initialize();
    if (available) {
      isListeningNotifier.value = true;
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

  void _stopRecording(String chatId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _speechService.stop();
    if (_messageController.text.isNotEmpty) {
      _sendMessage(chatId);
    }
    _messageController.clear();
    isListeningNotifier.value = false;
  }

  Widget _buildInputArea(String chatId) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo),
            onPressed: () => _filePickerService.pickAndUploadFile(chatId,
                isPhoto: true), // Pass chatId
          ),
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () =>
                _filePickerService.pickAndUploadFile(chatId), // Pass chatId
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
                    _stopRecording(chatId);
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
              onSubmitted: (_) => _sendMessage(chatId),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _sendMessage(chatId),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String chatId) async {
    if (_messageController.text.isEmpty) return;

    final userMessage = _messageController.text;
    try {
      // Send the user's message
      await _firebaseService.sendMessage(chatId, userMessage, 'text', 'User');
      _messageController.clear();
      _focusNode.requestFocus();
      _scrollToBottom();

      // Fetch AI's response and send it
      String aiMessage = await fetchGeminiResponse(userMessage);
      await _firebaseService.sendMessage(chatId, aiMessage, 'text', 'AI');
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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
      body: FutureBuilder<String>(
        future: chatIdFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final chatId = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firebaseService.chatCollection
                      .doc(chatId)
                      .collection('messages')
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

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

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
                                        color: Colors.grey.withOpacity(0.3),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    color: (isCurrentUser
                                        ? const Color(0xFF8EC6C5)
                                        : const Color(0xFFD9EAD3)),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: type == 'image'
                                      ? InkWell(
                                          onTap: () => _openFile(message),
                                          child: Image.network(
                                            message,
                                            width: 100,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.black54);
                                            },
                                          ),
                                        )
                                      : type == 'text'
                                          ? isCurrentUser
                                              ? Text(
                                                  message,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: isCurrentUser
                                                        ? Colors.white
                                                        : Colors.black54,
                                                  ),
                                                )
                                              : MarkdownBody(
                                                  data: message,
                                                  styleSheet:
                                                      MarkdownStyleSheet(
                                                    p: TextStyle(
                                                      fontSize: 15,
                                                      color: isCurrentUser
                                                          ? Colors.white
                                                          : Colors.black54,
                                                    ),
                                                  ),
                                                )
                                          : InkWell(
                                              onTap: () => _openFile(message),
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
                                                            : Colors.black54,
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
              _buildInputArea(chatId),
            ],
          );
        },
      ),
    );
  }
}
