import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/providers/capture_provider.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/utils/date_utils.dart';
import 'package:personal_memory_os/core/router/app_router.dart';
import 'package:personal_memory_os/shared/widgets/reminder_card.dart';
import 'package:personal_memory_os/shared/widgets/event_card.dart';
import 'package:personal_memory_os/shared/widgets/capture_card.dart';
import 'package:personal_memory_os/shared/widgets/section_header.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';
import 'package:personal_memory_os/features/capture/widgets/action_suggestions_section.dart';
import 'package:personal_memory_os/features/today/widgets/daily_brief_card.dart';
import 'package:personal_memory_os/features/today/widgets/now_card.dart';
import 'package:personal_memory_os/features/today/widgets/quick_capture_bar.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    await Future.wait([
      context.read<ReminderProvider>().loadReminders(),
      context.read<EventProvider>().loadEvents(),
      context.read<CaptureProvider>().loadCaptures(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            slivers: [
              _buildHeader(context),
              _buildBrief(context),
              const SliverToBoxAdapter(child: ActionSuggestionsSection()),
              _buildNowSection(context),
              _buildTodayReminders(context),
              _buildTodayEvents(context),
              _buildUpcoming(context),
              _buildRecentMemory(context),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildBrief(BuildContext context) {
    final brief = buildBrief(
      reminders: context.watch<ReminderProvider>().reminders,
      events: context.watch<EventProvider>().events,
      now: DateTime.now(),
    );
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: DailyBriefCard(brief: brief),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppDateUtils.greeting(),
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  user?.displayName?.split(' ').first ?? 'There',
                  style: AppTextStyles.displayMedium,
                ),
              ],
            ),
            GestureDetector(
              onTap: () => context.push(AppRoutes.memorySearch),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowSection(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, _) {
        final next = provider.nextReminder;
        if (next.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Now'),
              NowCard(
                reminder: next.first,
                onOpen: () => context.push(AppRoutes.reminders),
                onSnooze: () =>
                    context.read<ReminderProvider>().snoozeReminder(
                          next.first.id,
                          const Duration(minutes: 15),
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayReminders(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, _) {
        final reminders = provider.todayReminders;
        final overdue = provider.overdueReminders;

        if (reminders.isEmpty && overdue.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Today',
                action: 'See all',
                onAction: () => context.push(AppRoutes.reminders),
              ),
              if (overdue.isNotEmpty) ...[
                for (final r in overdue.take(2))
                  ReminderCard(
                    reminder: r,
                    onComplete: () =>
                        context.read<ReminderProvider>().completeReminder(r.id),
                    onSnooze: () =>
                        context.read<ReminderProvider>().snoozeReminder(
                              r.id,
                              const Duration(minutes: 30),
                            ),
                    onTap: () => context.push(AppRoutes.reminders),
                  ),
              ],
              for (final r in reminders.take(3))
                ReminderCard(
                  reminder: r,
                  onComplete: () =>
                      context.read<ReminderProvider>().completeReminder(r.id),
                  onSnooze: () =>
                      context.read<ReminderProvider>().snoozeReminder(
                            r.id,
                            const Duration(minutes: 30),
                          ),
                  onTap: () => context.push(AppRoutes.reminders),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayEvents(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, provider, _) {
        final events = provider.todayEvents;
        if (events.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: "Today's Events"),
              for (final e in events)
                EventCard(
                  event: e,
                  onTap: () => context.push('/events/${e.id}'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcoming(BuildContext context) {
    return Consumer2<ReminderProvider, EventProvider>(
      builder: (context, remindersP, eventsP, _) {
        final upcoming = eventsP.upcomingEvents.take(3).toList();
        if (upcoming.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Upcoming',
                action: 'All events',
                onAction: () => context.push(AppRoutes.memory),
              ),
              for (final e in upcoming)
                EventCard(
                  event: e,
                  onTap: () => context.push('/events/${e.id}'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentMemory(BuildContext context) {
    return Consumer<CaptureProvider>(
      builder: (context, provider, _) {
        final recent = provider.recentCaptures;
        if (recent.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Recent Memory',
                action: 'View all',
                onAction: () => context.push(AppRoutes.memory),
              ),
              for (final c in recent.take(3))
                CaptureCard(
                  capture: c,
                  onTap: () => context.push(AppRoutes.memory),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickCapture(context),
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text(
        'Capture',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showQuickCapture(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickCaptureBar(
        onCamera: () {
          Navigator.pop(context);
          context.push(AppRoutes.capture);
        },
        onVoice: () {
          Navigator.pop(context);
          context.push(AppRoutes.capture);
        },
        onText: () {
          Navigator.pop(context);
          context.push(AppRoutes.capture);
        },
        onReminder: () {
          Navigator.pop(context);
          context.push(AppRoutes.reminderCreate);
        },
        onEvent: () {
          Navigator.pop(context);
          context.push(AppRoutes.eventCreate);
        },
      ),
    );
  }
}
