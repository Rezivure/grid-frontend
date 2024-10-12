// lib/widgets/emoji_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_emoji/flutter_emoji.dart';

class EmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;

  EmojiPicker({required this.onEmojiSelected});

  @override
  Widget build(BuildContext context) {
    var parser = EmojiParser();
    var emojis = parser.emojify(':smile: :heart: :octopus: :coffee: :butterfly:').split(' ');

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select an Profile Avatar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Divider(),
          Wrap(
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  onEmojiSelected(parser.unemojify(emoji));
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: 30),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
