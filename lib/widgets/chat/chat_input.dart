import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ChatInput extends StatefulWidget {
  final Color chatColor;
  final Function(String) onSendMessage;
  final Function(File) onSendImage;
  final Function(String) onEmojiSelected;

  const ChatInput({
    Key? key,
    required this.chatColor,
    required this.onSendMessage,
    required this.onSendImage,
    required this.onEmojiSelected,
  }) : super(key: key);

  @override
  _ChatInputState createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isComposing = false;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.removeListener(_handleFocusChange);
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_messageFocusNode.hasFocus && mounted) {
      setState(() {
        _showEmojiPicker = false;
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      widget.onSendMessage(_messageController.text);
      _messageController.clear();
      setState(() {
        _isComposing = false;
      });
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) {
        _messageFocusNode.unfocus();
      } else {
        _messageFocusNode.requestFocus();
      }
    });
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      widget.onSendImage(File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                // Camera button
                IconButton(
                  icon: Icon(
                    Icons.camera_alt,
                    color: widget.chatColor,
                  ),
                  onPressed: _takePicture,
                ),

                // Text input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: _isComposing
                              ? widget.chatColor
                              : Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: _messageController,
                              focusNode: _messageFocusNode,
                              decoration: const InputDecoration(
                                hintText: 'Type a message',
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (text) {
                                setState(() {
                                  _isComposing = text.isNotEmpty;
                                });
                              },
                              onSubmitted: (_) =>
                                  _isComposing ? _sendMessage() : null,
                            ),
                          ),
                        ),

                        // Emoji button
                        IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: _showEmojiPicker
                                ? widget.chatColor
                                : Colors.grey[600],
                          ),
                          onPressed: _toggleEmojiPicker,
                        ),
                      ],
                    ),
                  ),
                ),

                // Send button
                IconButton(
                  icon: Icon(
                    Icons.send,
                    color: _isComposing ? widget.chatColor : Colors.grey[400],
                  ),
                  onPressed: _isComposing ? _sendMessage : null,
                ),
              ],
            ),
          ),
        ),

        // Emoji picker
        if (_showEmojiPicker)
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                widget.onEmojiSelected(emoji.emoji);
                _onEmojiSelected(emoji.emoji);
              },
              config: Config(
                height: 250,
                emojiViewConfig: EmojiViewConfig(emojiSizeMax: 32.0),
                viewOrderConfig: const ViewOrderConfig(
                  top: EmojiPickerItem.categoryBar,
                  middle: EmojiPickerItem.emojiView,
                  bottom: EmojiPickerItem.searchBar,
                ),
                skinToneConfig: const SkinToneConfig(
                  dialogBackgroundColor: Colors.white,
                  indicatorColor: Colors.grey,
                ),
                categoryViewConfig: CategoryViewConfig(
                  iconColor: Colors.grey,
                  iconColorSelected: widget.chatColor,
                  indicatorColor: widget.chatColor,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: Colors.transparent,
                  buttonColor: widget.chatColor,
                ),
                searchViewConfig: const SearchViewConfig(
                  buttonIconColor: Colors.black,
                  backgroundColor: Colors.white,
                ),
                checkPlatformCompatibility: true,
              ),
            ),
          ),
      ],
    );
  }

  void _onEmojiSelected(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;

    if (selection.baseOffset < 0) {
      _messageController.text = text + emoji;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    } else {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      _messageController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.baseOffset + emoji.length,
        ),
      );
    }

    setState(() {
      _isComposing = _messageController.text.isNotEmpty;
    });
  }
}
