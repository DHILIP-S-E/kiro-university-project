import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/providers/capture_provider.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/shared/widgets/capture_card.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    final event = context.watch<EventProvider>().getEventById(eventId);

    if (event == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Text('Event not found', style: AppTextStyles.bodyLarge),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, event),
          _buildDeadlines(event),
          _buildCaptures(context, event),
          _buildMemorySection(context, event),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.capture),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Capture'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Event event) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      expandedHeight: 200,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryLight,
                AppColors.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _EventTypeBadge(type: event.eventType),
                  const SizedBox(height: 8),
                  Text(event.title,
                      style: AppTextStyles.displayMedium,
                      maxLines: 2),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        AppDateUtils.formatDateTime(event.startAt),
                        style: AppTextStyles.bodyMedium,
                      ),
                      if (event.organizer != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.business,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(event.organizer!,
                            style: AppTextStyles.bodyMedium),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlines(Event event) {
    if (event.deadlines.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'DEADLINES',
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          ...event.deadlines.map(
            (d) => Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: d.deadlineAt.isBefore(
                          DateTime.now().add(const Duration(days: 3)))
                      ? AppColors.urgent.withOpacity(0.4)
                      : AppColors.cardBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: d.deadlineAt.isBefore(
                            DateTime.now().add(const Duration(days: 3)))
                        ? AppColors.urgent
                        : AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title,
                            style: AppTextStyles.titleMedium),
                        Text(
                          AppDateUtils.formatDateTime(d.deadlineAt),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppDateUtils.timeUntil(d.deadlineAt),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: d.deadlineAt.isBefore(
                              DateTime.now().add(const Duration(days: 3)))
                          ? AppColors.urgent
                          : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptures(BuildContext context, Event event) {
    return SliverToBoxAdapter(
      child: Consumer<CaptureProvider>(
        builder: (context, provider, _) {
          final captures = provider.capturesForEvent(event.id);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CAPTURES',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      '${captures.length}',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              if (captures.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            color: AppColors.textMuted, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No captures yet. Tap the Capture button to add photos, voice notes, and notes.',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...captures
                    .take(5)
                    .map((c) => CaptureCard(capture: c)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemorySection(BuildContext context, Event event) {
    if (event.summaryId == null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'AI summary will appear here after you capture content from this event.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }
}

class _EventTypeBadge extends StatelessWidget {
  final EventType type;

  const _EventTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
