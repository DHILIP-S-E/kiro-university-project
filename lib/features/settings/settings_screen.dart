import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/theme/app_theme.dart';
import 'package:personal_memory_os/core/router/app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Profile', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 20),
                    _buildProfileCard(user),
                  ],
                ),
              ),
            ),
            _buildSection('Notifications', [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notification preferences',
                subtitle: 'Push, alarm, quiet hours',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.alarm,
                title: 'Default alarm settings',
                subtitle: 'Sound, vibration, snooze duration',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.schedule,
                title: 'Quiet hours',
                subtitle: 'No notifications between 10 PM – 7 AM',
                onTap: () {},
              ),
            ]),
            _buildSection('AI & Processing', [
              _SettingsTile(
                icon: Icons.psychology_outlined,
                title: 'AI preferences',
                subtitle: 'Model selection, auto-summarize',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Auto-extract action items',
                subtitle: 'Enabled',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: AppColors.accent,
                ),
                onTap: null,
              ),
              _SettingsTile(
                icon: Icons.summarize_outlined,
                title: 'Auto-generate summaries',
                subtitle: 'After capturing 5+ items',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: AppColors.accent,
                ),
                onTap: null,
              ),
            ]),
            _buildSection('Storage', [
              _SettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Connected storage',
                subtitle: 'AWS S3 • Personal bucket',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.storage_outlined,
                title: 'Cache & local storage',
                subtitle: 'Manage offline data',
                onTap: () {},
              ),
            ]),
            _buildSection('Privacy & Security', [
              _SettingsTile(
                icon: Icons.lock_outlined,
                title: 'Encryption',
                subtitle: 'AWS KMS — enabled',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Export my data',
                subtitle: 'JSON, Markdown, or ZIP',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Delete all data',
                subtitle: 'Permanently remove everything',
                titleColor: AppColors.urgent,
                onTap: () => _showDeleteDialog(context),
              ),
            ]),
            _buildSection('Account', [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Personal Memory OS v1.0.0',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.logout,
                title: 'Sign out',
                titleColor: AppColors.urgent,
                onTap: () => _signOut(context),
              ),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.accent.withOpacity(0.2),
            backgroundImage: user?.avatarUrl != null
                ? NetworkImage(user!.avatarUrl!)
                : null,
            child: user?.avatarUrl == null
                ? Text(
                    (user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0]
                            : '?')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'User',
                  style: AppTextStyles.titleMedium,
                ),
                Text(
                  user?.email ?? '',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Amazon Cognito',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.textMuted, letterSpacing: 1.2),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: tiles
                  .asMap()
                  .entries
                  .map(
                    (e) => Column(
                      children: [
                        e.value,
                        if (e.key < tiles.length - 1)
                          const Divider(
                              height: 1, indent: 52, endIndent: 0),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _signOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?', style: AppTextStyles.titleMedium),
        content: const Text(
          'Your data is safely stored in the cloud.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete all data?',
            style: AppTextStyles.titleMedium),
        content: const Text(
          'This permanently deletes all your reminders, events, captures, and memories. This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgent),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon,
          color: titleColor ?? AppColors.textSecondary, size: 22),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right,
                  color: AppColors.textMuted, size: 18)
              : null),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
