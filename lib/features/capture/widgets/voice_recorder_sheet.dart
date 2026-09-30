import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class VoiceRecorderSheet extends StatefulWidget {
  final Function(File file) onSaved;

  const VoiceRecorderSheet({super.key, required this.onSaved});

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  bool _isRecording = false;
  int _elapsed = 0;
  Timer? _timer;

  void _startRecording() {
    // In production, integrate record package or flutter_sound
    setState(() {
      _isRecording = true;
      _elapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed++);
    });
  }

  void _stopRecording() {
    _timer?.cancel();
    setState(() => _isRecording = false);
  }

  String get _formattedTime {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
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
          const Text('Voice Note', style: AppTextStyles.titleLarge),
          const SizedBox(height: 32),
          // Waveform placeholder
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isRecording
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        20,
                        (i) => AnimatedContainer(
                          duration: Duration(milliseconds: 200 + i * 50),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 3,
                          height: (10 + (i % 5) * 10).toDouble(),
                          decoration: BoxDecoration(
                            color: AppColors.captureVoice,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      _elapsed > 0 ? _formattedTime : 'Tap to record',
                      style: AppTextStyles.bodyMedium,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? _formattedTime : '00:00',
            style: AppTextStyles.displayMedium.copyWith(
              color: _isRecording ? AppColors.captureVoice : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_elapsed > 0 && !_isRecording) ...[
                OutlinedButton(
                  onPressed: () {
                    setState(() => _elapsed = 0);
                  },
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // widget.onSaved(recordedFile);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ] else ...[
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : _startRecording,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? AppColors.urgent
                          : AppColors.captureVoice,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? AppColors.urgent
                                  : AppColors.captureVoice)
                              .withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording ? 'Tap to stop' : 'Tap to start',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
