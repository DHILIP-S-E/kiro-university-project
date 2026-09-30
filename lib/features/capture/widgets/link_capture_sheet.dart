import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class LinkCaptureSheet extends StatefulWidget {
  final Function(String url) onSaved;

  const LinkCaptureSheet({super.key, required this.onSaved});

  @override
  State<LinkCaptureSheet> createState() => _LinkCaptureSheetState();
}

class _LinkCaptureSheetState extends State<LinkCaptureSheet> {
  final _controller = TextEditingController();

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _controller.text = data!.text!;
    }
  }

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
          const Text('Save Link', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Paste a URL to an event, article, or resource',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: 'https://…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, size: 18),
                onPressed: _paste,
                tooltip: 'Paste from clipboard',
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final url = _controller.text.trim();
                if (url.isNotEmpty) {
                  widget.onSaved(url);
                }
                Navigator.pop(context);
              },
              child: const Text('Save Link'),
            ),
          ),
        ],
      ),
    );
  }
}
