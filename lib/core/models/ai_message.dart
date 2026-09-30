enum MessageRole { user, assistant }

class AiMessageSource {
  final String eventTitle;
  final String? captureType;
  final String? captureRef;

  const AiMessageSource({
    required this.eventTitle,
    this.captureType,
    this.captureRef,
  });

  factory AiMessageSource.fromJson(Map<String, dynamic> json) =>
      AiMessageSource(
        eventTitle: json['eventTitle'],
        captureType: json['captureType'],
        captureRef: json['captureRef'],
      );

  Map<String, dynamic> toJson() => {
        'eventTitle': eventTitle,
        'captureType': captureType,
        'captureRef': captureRef,
      };
}

class AiMessage {
  final String id;
  final MessageRole role;
  final String content;
  final List<AiMessageSource> sources;
  final DateTime timestamp;
  final bool isError;

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sources = const [],
    required this.timestamp,
    this.isError = false,
  });
}

class AiAnswer {
  final String answer;
  final List<AiMessageSource> sources;

  const AiAnswer({required this.answer, this.sources = const []});
}
