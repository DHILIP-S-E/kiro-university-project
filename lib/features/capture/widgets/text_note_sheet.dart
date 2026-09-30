import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class TextNoteSheet extends StatefulWidget {
  final Function(String text) onSaved;

  const TextNoteSheet({super.key, required this.onSaved});

  @override
  State<TextNoteSheet> createState() => _TextNoteSheetState();
}

class _TextNoteSheetState extends State<TextNoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Text Note', style: AppTextStyles.titleLarge),
              ),
              TextButton(
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    widget.onSaved(_controller.text.trim());
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 8,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Write anything… notes, ideas, observations',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
