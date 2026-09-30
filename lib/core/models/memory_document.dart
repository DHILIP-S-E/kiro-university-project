class MemoryDocument {
  final String id;
  final String userId;
  final String? eventId;
  final String? eventTitle;
  final String? overview;
  final List<String> keyTopics;
  final List<String> keyTakeaways;
  final List<String> thingsLearned;
  final List<String> importantPeople;
  final List<String> resources;
  final List<String> links;
  final List<String> questions;
  final List<String> decisions;
  final List<ActionItemRef> actionItems;
  final List<DeadlineRef> deadlines;
  final List<String> relatedEventIds;
  final DateTime eventDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryDocument({
    required this.id,
    required this.userId,
    this.eventId,
    this.eventTitle,
    this.overview,
    this.keyTopics = const [],
    this.keyTakeaways = const [],
    this.thingsLearned = const [],
    this.importantPeople = const [],
    this.resources = const [],
    this.links = const [],
    this.questions = const [],
    this.decisions = const [],
    this.actionItems = const [],
    this.deadlines = const [],
    this.relatedEventIds = const [],
    required this.eventDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemoryDocument.fromJson(Map<String, dynamic> json) => MemoryDocument(
        id: json['id'],
        userId: json['userId'],
        eventId: json['eventId'],
        eventTitle: json['eventTitle'],
        overview: json['overview'],
        keyTopics: List<String>.from(json['keyTopics'] ?? []),
        keyTakeaways: List<String>.from(json['keyTakeaways'] ?? []),
        thingsLearned: List<String>.from(json['thingsLearned'] ?? []),
        importantPeople: List<String>.from(json['importantPeople'] ?? []),
        resources: List<String>.from(json['resources'] ?? []),
        links: List<String>.from(json['links'] ?? []),
        questions: List<String>.from(json['questions'] ?? []),
        decisions: List<String>.from(json['decisions'] ?? []),
        actionItems: (json['actionItems'] as List<dynamic>? ?? [])
            .map((a) => ActionItemRef.fromJson(a))
            .toList(),
        deadlines: (json['deadlines'] as List<dynamic>? ?? [])
            .map((d) => DeadlineRef.fromJson(d))
            .toList(),
        relatedEventIds: List<String>.from(json['relatedEventIds'] ?? []),
        eventDate: DateTime.parse(json['eventDate']),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'overview': overview,
        'keyTopics': keyTopics,
        'keyTakeaways': keyTakeaways,
        'thingsLearned': thingsLearned,
        'importantPeople': importantPeople,
        'resources': resources,
        'links': links,
        'questions': questions,
        'decisions': decisions,
        'actionItems': actionItems.map((a) => a.toJson()).toList(),
        'deadlines': deadlines.map((d) => d.toJson()).toList(),
        'relatedEventIds': relatedEventIds,
        'eventDate': eventDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class ActionItemRef {
  final String title;
  final String? reminderId;
  final bool completed;

  const ActionItemRef({
    required this.title,
    this.reminderId,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'reminderId': reminderId,
        'completed': completed,
      };

  factory ActionItemRef.fromJson(Map<String, dynamic> json) => ActionItemRef(
        title: json['title'],
        reminderId: json['reminderId'],
        completed: json['completed'] ?? false,
      );
}

class DeadlineRef {
  final String title;
  final DateTime deadlineAt;
  final bool hasReminder;

  const DeadlineRef({
    required this.title,
    required this.deadlineAt,
    this.hasReminder = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'deadlineAt': deadlineAt.toIso8601String(),
        'hasReminder': hasReminder,
      };

  factory DeadlineRef.fromJson(Map<String, dynamic> json) => DeadlineRef(
        title: json['title'],
        deadlineAt: DateTime.parse(json['deadlineAt']),
        hasReminder: json['hasReminder'] ?? false,
      );
}
