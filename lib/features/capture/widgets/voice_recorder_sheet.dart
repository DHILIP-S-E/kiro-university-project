import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:personal_memory_os/core/services/audio_service.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';

class VoiceRecorderSheet extends StatefulWidget {
  final Function(File file) onSaved;

  const VoiceRecorderSheet({super.key, required this.onSaved});

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  bool _isRecording = false;
  bool _isStarting = false;
  int _elapsed = 0;
  File? _recordedFile;
  Timer? _timer;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    // Cancel any active recording without saving when sheet is dismissed
    AudioService.cancelRecording();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isStarting = true;
      _error = null;
      _recordedFile = null;
      _elapsed = 0;
    });
    try {
      await AudioService.startRecording();
      setState(() {
        _isRecording = true;
        _isStarting = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed++);
      });
    } catch (e) {
      setState(() {
        _isStarting = false;
        _error = 'Microphone permission denied. Please allow access in Settings.';
      });
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final file = await AudioService.stopRecording();
    setState(() {
      _isRecording = false;
      _recordedFile = file;
    });
  }

  void _discard() {
    setState(() {
      _recordedFile = null;
      _elapsed = 0;
    });
  }

  void _save() {
    if (_recordedFile != null) {
      widget.onSaved(_recordedFile!);
    }
    Navigator.pop(context);
  }

  String get _formattedTime {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
          // Drag handle
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
          const SizedBox(height: 28),

          // Error banner
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.urgent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.urgent.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.urgent),
                textAlign: TextAlign.center,
              ),
            ),

          // Waveform visualiser
          Container(
            height: 64,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _isRecording
                  ? _WaveformAnimation()
                  : Text(
                      _recordedFile != null
                          ? 'Recording saved ($_formattedTime)'
                          : 'Tap to start recording',
                      style: AppTextStyles.bodyMedium,
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Elapsed timer
          Text(
            _formattedTime,
            style: AppTextStyles.displayMedium.copyWith(
              color: _isRecording
                  ? AppColors.captureVoice
                  : AppColors.textMuted,
            ),
          ),

          const SizedBox(height: 24),

          // Controls
          if (_recordedFile != null) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _discard,
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Semantics(
              button: true,
              label: _isRecording ? 'Stop recording' : 'Start recording',
              child: GestureDetector(
                onTap: _isStarting
                    ? null
                    : (_isRecording ? _stopRecording : _startRecording),
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
                            .withValues(alpha: 0.35),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _isStarting
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isStarting
                  ? 'Requesting permission…'
                  : _isRecording
                      ? 'Tap to stop'
                      : 'Tap to record',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Simple animated waveform shown during recording.
class _WaveformAnimation extends StatefulWidget {
  @override
  State<_WaveformAnimation> createState() => _WaveformAnimationState();
}

class _WaveformAnimationState extends State<_WaveformAnimation>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      16,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 60),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _controllers.map((ctrl) {
        return AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: 8 + ctrl.value * 36,
            decoration: BoxDecoration(
              color: AppColors.captureVoice,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}
