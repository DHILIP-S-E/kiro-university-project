enum ReminderType {
  time,
  date,
  relative,
  recurring,
  deadline,
  followUp,
  conditional,
  multiStage,
}

enum ReminderStatus { active, snoozed, completed, missed, cancelled, overdue }

enum ReminderPriority { high, medium, low }

enum ReminderSource { manual, nlp, aiExtracted, eventPolicy }

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final ReminderType reminderType;
  final DateTime? scheduledAt;
  final String timezone;
  final ReminderPriority priority;
  final ReminderStatus status;
  final bool alarmEnabled;
  final bool notificationEnabled;
  final String? recurrenceRule; // RFC 5545 RRULE
  final ReminderSource source;
  final String? contextId; // linked event or capture
  final List<ReminderOffset> offsets;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Sync fields
  final String? serverId;
  final String syncStatus;

  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.reminderType,
    this.scheduledAt,
    this.timezone = 'UTC',
    this.priority = ReminderPriority.medium,
    this.status = ReminderStatus.active,
    this.alarmEnabled = true,
    this.notificationEnabled = true,
    this.recurrenceRule,
    this.source = ReminderSource.manual,
    this.contextId,
    this.offsets = const [],
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.syncStatus = 'LOCAL_ONLY',
  });

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    ReminderType? reminderType,
    DateTime? scheduledAt,
    String? timezone,
    ReminderPriority? priority,
    ReminderStatus? status,
    bool? alarmEnabled,
    bool? notificationEnabled,
    String? recurrenceRule,
    ReminderSource? source,
    String? contextId,
    List<ReminderOffset>? offsets,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? serverId,
    String? syncStatus,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      reminderType: reminderType ?? this.reminderType,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      timezone: timezone ?? this.timezone,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      source: source ?? this.source,
      contextId: contextId ?? this.contextId,
      offsets: offsets ?? this.offsets,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'description': description,
        'reminderType': reminderType.name,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'timezone': timezone,
        'priority': priority.name,
        'status': status.name,
        'alarmEnabled': alarmEnabled,
        'notificationEnabled': notificationEnabled,
        'recurrenceRule': recurrenceRule,
        'source': source.name,
        'contextId': contextId,
        'offsets': offsets.map((o) => o.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'serverId': serverId,
        'syncStatus': syncStatus,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
        id: json['id'],
        userId: json['userId'],
        title: json['title'],
        description: json['description'],
        reminderType: ReminderType.values.byName(json['reminderType']),
        scheduledAt: json['scheduledAt'] != null
            ? DateTime.parse(json['scheduledAt'])
            : null,
        timezone: json['timezone'] ?? 'UTC',
        priority: ReminderPriority.values.byName(json['priority'] ?? 'medium'),
        status: ReminderStatus.values.byName(json['status'] ?? 'active'),
        alarmEnabled: json['alarmEnabled'] ?? true,
        notificationEnabled: json['notificationEnabled'] ?? true,
        recurrenceRule: json['recurrenceRule'],
        source: ReminderSource.values.byName(json['source'] ?? 'manual'),
        contextId: json['contextId'],
        offsets: (json['offsets'] as List<dynamic>? ?? [])
            .map((o) => ReminderOffset.fromJson(o))
            .toList(),
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        serverId: json['serverId'],
        syncStatus: json['syncStatus'] ?? 'LOCAL_ONLY',
      );
}

class ReminderOffset {
  final String offset; // e.g. "-3d", "-1h", "-30m"
  final bool sent;

  const ReminderOffset({required this.offset, this.sent = false});

  Map<String, dynamic> toJson() => {'offset': offset, 'sent': sent};
  factory ReminderOffset.fromJson(Map<String, dynamic> json) =>
      ReminderOffset(offset: json['offset'], sent: json['sent'] ?? false);
}
