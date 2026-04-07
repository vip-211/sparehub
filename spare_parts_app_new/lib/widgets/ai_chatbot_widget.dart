import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';
import '../services/remote_client.dart';
import '../services/product_service.dart';
import '../models/product.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/ai_training_service.dart';
import '../services/settings_service.dart';

class AIChatbotWidget extends StatefulWidget {
  const AIChatbotWidget({super.key});

  @override
  State<AIChatbotWidget> createState() => _AIChatbotWidgetState();
}

class _AIChatbotWidgetState extends State<AIChatbotWidget> {
  bool _isOpen = false;
  final List<Map<String, dynamic>> _messages = [
    {
      'text':
          "Hello! I'm your Parts Mitra AI assistant. How can I help you today?",
      'isBot': true
    }
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final RemoteClient _remoteClient = RemoteClient();
  final ProductService _productService = ProductService();
  final AITrainingService _trainingService = AITrainingService();
  final ImagePicker _picker = ImagePicker();
  List<Product> _matches = [];
  String? _lastUserPrompt;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isBot': false});
      _controller.clear();
      _isLoading = true;
      _lastUserPrompt = text;
    });
    _scrollToBottom();

    try {
      final provider = SettingsService.getCachedRemoteSetting('AI_PROVIDER', 'gemini');
      final res = await _remoteClient.postJson(
        '/ai/chat',
        {'prompt': text},
        headers: {'X-AI-Provider': provider},
      );
      setState(() {
        _messages.add({
          'text': res['response'] ?? "I couldn't generate a response.",
          'isBot': true,
          'prompt': text,
        });
      });
    } catch (e) {
      try {
        final List<Product> suggestions =
            await _productService.searchProducts(text);
        if (suggestions.isNotEmpty) {
          final top = suggestions.take(5).toList();
          final response = StringBuffer();
          response.writeln(
              "AI service is unavailable right now. Here are some matching parts:");
          for (final p in top) {
            response.writeln(
                "- ${p.name} (${p.partNumber ?? 'N/A'}) • ₹${p.sellingPrice}");
          }
          setState(() {
            _messages.add({
              'text': response.toString(),
              'isBot': true,
              'prompt': text,
            });
          });
        } else {
          setState(() {
            _messages.add({
              'text':
                  "AI service is currently unavailable and I couldn't find matching parts.",
              'isBot': true,
              'prompt': text,
            });
          });
        }
      } catch (_) {
        setState(() {
          _messages.add({
            'text':
                "AI service is currently unavailable. Please try again later.",
            'isBot': true,
            'prompt': text,
          });
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _handlePhotoSearch() async {
    try {
      final XFile? img = await _picker.pickImage(source: ImageSource.gallery);
      if (img == null) return;
      setState(() {
        _isLoading = true;
        _messages.add({'text': 'Analyzing image...', 'isBot': true});
      });
      final bytes = await img.readAsBytes();
      final res = await _remoteClient.postMultipart(
        '/ai/search/photo',
        headers: {'X-AI-Provider': 'gemini'},
        fileField: 'image',
        fileName: img.name,
        bytes: bytes,
      );
      setState(() {
        _messages.add({
          'text': res['response'] ?? 'No response',
          'isBot': true,
          'prompt': 'Search by photo: ${img.name}'
        });
      });
      final products = await _productService
          .searchProducts((res['response'] ?? '') as String);
      setState(() {
        _matches = products;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'text': 'Failed to analyze image.',
          'isBot': true,
          'prompt': 'Search by photo'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleVoiceSearch() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      setState(() {
        _isLoading = true;
        _messages.add({'text': 'Processing audio query...', 'isBot': true});
      });
      final res = await _remoteClient.postMultipart(
        '/ai/search/voice',
        headers: {'X-AI-Provider': 'gemini'},
        fileField: 'audio',
        fileName: file.name,
        bytes: file.bytes!,
      );
      setState(() {
        _messages.add({
          'text': res['response'] ?? 'No response',
          'isBot': true,
          'prompt': 'Search by voice: ${file.name}'
        });
      });
      final products = await _productService
          .searchProducts((res['response'] ?? '') as String);
      setState(() {
        _matches = products;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'text': 'Failed to process audio.',
          'isBot': true,
          'prompt': 'Search by voice'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleFeedback(
      String prompt, String response, bool isPositive) async {
    try {
      await _trainingService.submitFeedback(
        prompt: prompt,
        response: response,
        isPositive: isPositive,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPositive
                ? 'Thank you for your feedback!'
                : 'Feedback received. We will use this to improve.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Silently fail or log
    }
  }

  Future<void> _showCorrectionDialog(
      String prompt, String originalResponse) async {
    final TextEditingController correctionController =
        TextEditingController(text: originalResponse);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Train AI'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help us improve! What should have been the correct response?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: correctionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter correct response...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final corrected = correctionController.text.trim();
              if (corrected.isNotEmpty && corrected != originalResponse) {
                await _trainingService.submitCorrection(
                  prompt: prompt,
                  originalResponse: originalResponse,
                  correctedResponse: corrected,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Thank you! AI trained.')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80, // Moved up to avoid overlap with existing FABs
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isOpen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.5,
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white24,
                            radius: 14,
                            child: Icon(Icons.smart_toy,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parts Mitra AI',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Online',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            onPressed: () => setState(() => _isOpen = false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Messages
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isBot = msg['isBot'] as bool;
                            return Align(
                              alignment: isBot
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: isBot
                                    ? CrossAxisAlignment.start
                                    : CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isBot
                                          ? Colors.white
                                          : const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isBot
                                            ? Radius.zero
                                            : const Radius.circular(16),
                                        bottomRight: isBot
                                            ? const Radius.circular(16)
                                            : Radius.zero,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      msg['text'] as String,
                                      style: TextStyle(
                                        color: isBot
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  if (isBot &&
                                      index >
                                          0) // Don't show for first hello msg
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.thumb_up_outlined,
                                                size: 16,
                                                color: Colors.grey),
                                            onPressed: () => _handleFeedback(
                                                msg['prompt'] ?? 'N/A',
                                                msg['text'] as String,
                                                true),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            tooltip: 'Helpful',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.thumb_down_outlined,
                                                size: 16,
                                                color: Colors.grey),
                                            onPressed: () => _handleFeedback(
                                                msg['prompt'] ?? 'N/A',
                                                msg['text'] as String,
                                                false),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            tooltip: 'Not helpful',
                                          ),
                                          const SizedBox(width: 8),
                                          // Only Admins can train the AI
                                          Consumer<AuthProvider>(
                                            builder: (context, auth, _) {
                                              final isAdmin = auth.user?.roles
                                                      .any((r) =>
                                                          r == 'ROLE_ADMIN' ||
                                                          r ==
                                                              'ROLE_SUPER_MANAGER') ??
                                                  false;
                                              if (!isAdmin)
                                                return const SizedBox.shrink();

                                              return TextButton.icon(
                                                onPressed: () =>
                                                    _showCorrectionDialog(
                                                        msg['prompt'] ?? 'N/A',
                                                        msg['text'] as String),
                                                icon: const Icon(Icons.edit_note,
                                                    size: 16),
                                                label: const Text('Train AI',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  foregroundColor: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (!isBot) const SizedBox(height: 12),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_matches.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        color: const Color(0xFFF8FAFC),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Matched Products',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ..._matches.take(6).map((p) {
                              final displayPrice = p.sellingPrice;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.build,
                                          color: Colors.grey),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text('Part: ${p.partNumber ?? 'N/A'}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${displayPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Builder(builder: (ctx) {
                                      return TextButton(
                                        onPressed: () {
                                          final cart =
                                              Provider.of<CartProvider>(ctx,
                                                  listen: false);
                                          cart.addItem(p, displayPrice);
                                          try {
                                            _trainingService.submitVoiceAdd(
                                              query: _lastUserPrompt ?? 'chat',
                                              productId: p.id,
                                              productName: p.name,
                                              price: displayPrice,
                                            );
                                          } catch (_) {}
                                        },
                                        child: const Text('ADD'),
                                      );
                                    }),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () async {
                                        try {
                                          final res =
                                              await _remoteClient.postJson(
                                            '/ai/order',
                                            {'productId': p.id, 'quantity': 1},
                                          );
                                          final msg =
                                              'Order placed: #${res['orderId']} • ₹${res['total']}';
                                          setState(() {
                                            _messages.add(
                                                {'text': msg, 'isBot': true});
                                          });
                                        } catch (e) {
                                          setState(() {
                                            _messages.add({
                                              'text': 'Failed to place order.',
                                              'isBot': true
                                            });
                                          });
                                        }
                                      },
                                      child: const Text('ORDER'),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    if (_isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        color: const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI is typing...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Input
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image,
                                color: Color(0xFF2563EB)),
                            onPressed: _handlePhotoSearch,
                            tooltip: 'Search by photo',
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.mic, color: Color(0xFF2563EB)),
                            onPressed: _handleVoiceSearch,
                            tooltip: 'Search by voice (upload audio)',
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Ask about parts...',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade400),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _handleSend(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _handleSend,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          FloatingActionButton(
            onPressed: () => setState(() => _isOpen = !_isOpen),
            backgroundColor: const Color(0xFF2563EB),
            elevation: 8,
            child: Icon(_isOpen ? Icons.keyboard_arrow_down : Icons.smart_toy,
                color: Colors.white),
          ),
        ],
      ),
    );
  }
}
