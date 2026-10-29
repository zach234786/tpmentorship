import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/session.dart';
// the session data type
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
// live firestore providers
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/widgets/session_card.dart';
// the session card widget

class ProfileScreen extends ConsumerWidget {
// users own profile page - now fed by the live firestore profile
// also shows the completed-sessions count from the aggregation query
  final String userName;
  // fallback name if the firestore profile hasnt loaded yet

  // functions passed in from the parent to handle button taps
  final VoidCallback? onEditProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;
  final ValueChanged<Session>? onSessionTap;
  final VoidCallback? onSeeMore;
  final VoidCallback? onGoPremium;
  final VoidCallback? onBack;

  const ProfileScreen({
    super.key,
    required this.userName,
    this.onEditProfile,
    this.onSettings,
    this.onLogout,
    this.onSessionTap,
    this.onSeeMore,
    this.onGoPremium,
    this.onBack,
  });

  // turns a date into a string like "17 May 2026"
  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // the last day of the month that the given date falls in, eg passing
  // any date in July returns 31 Jul <year> - used to show "active until
  // end of month" after cancelling premium
  DateTime _endOfMonth(DateTime date) {
    final firstOfNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstOfNextMonth.subtract(const Duration(days: 1));
  }

  // confirms then cancels premium (feedback: AlertDialog before an
  // irreversible-feeling action, same pattern as deleting a session)
  Future<void> _confirmCancelPremium(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkCardBg,
        title: Text('Cancel Membership',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'You will keep Premium access until the end of this month, '
          'then it will not renew.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep Premium',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Cancel Membership',
                style: TextStyle(
                    color: AppTheme.tpRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    try {
      await ref.read(userServiceProvider).cancelPremium(user.uid);
      if (context.mounted) {
        showAppSnackBar(context, 'Membership cancelled', success: true);
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, 'Could not cancel. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    // the live firestore profile (null until it loads, or on error eg offline)
    final sessionsAsync = ref.watch(mySessionsProvider);
    // this student's sessions, live
    final completedCount = ref.watch(completedSessionsCountProvider).valueOrNull;
    // how many sessions completed - from the firestore count() aggregation

    // use profile values when loaded, sensible fallbacks when not
    final displayName =
        (profile?.fullName.isNotEmpty ?? false) ? profile!.fullName : userName;
    final courseLine = profile == null || profile.course.isEmpty
        ? 'Set your course in Edit Profile'
        : '${profile.course}'
            '${profile.academicYear.isEmpty ? '' : ' (${profile.academicYear})'}';
    final bio = profile == null || profile.bio.isEmpty
        ? 'Tell mentors about yourself in Edit Profile '
        : '${profile.bio} ';
    final isPremium = profile?.isPremium ?? false;
    final premiumCancelled = profile?.premiumCancelled ?? false;

    return SingleChildScrollView(
    // whole screen scrolls
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // back arrow and title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Icon(Icons.arrow_back_ios,
                      color: AppTheme.textPrimary, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'Profile',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isPremium) ...[
                  // premium badge unlocked by the NETS QR payment
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium,
                      color: Colors.amber, size: 22),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // main profile card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCardBg,
              border: Border.all(color: AppTheme.darkBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // profile picture
                    Stack(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.tpRed, width: 3),
                            color: AppTheme.darkBg,
                          ),
                          child: Icon(Icons.person,
                              color: AppTheme.textSecondary, size: 36),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                              border: Border.all(color: AppTheme.darkCardBg, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // name, course and a short bio and read more
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            courseLine,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              text: bio,
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11, height: 1.4),
                              children: [
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: onEditProfile,
                                    child: Text(
                                      '...Edit',
                                      style: TextStyle(
                                        color: AppTheme.tpRed,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile != null) ...[
                      const SizedBox(width: 8),
                      // role badge - Student, or Student & Mentor after
                      // signing up as a mentor (see become_mentor_screen.dart)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.tpRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.tpRed.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          profile.role,
                          style: TextStyle(
                            color: AppTheme.tpRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // two info boxes, account created date and student id
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: AppTheme.tpRed, size: 16),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Created At:',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary, fontSize: 10)),
                                Text(
                                    profile == null
                                        ? '-'
                                        : _formatDate(profile.createdAt),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.darkBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.badge, color: AppTheme.tpRed, size: 16),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Student ID:',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary, fontSize: 10)),
                                Text(
                                    profile == null ||
                                            profile.studentId.isEmpty
                                        ? '-'
                                        : profile.studentId,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // edit profile settings and logout buttons
                Row(
                  children: [
                    Expanded(
                      child: _ProfileActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Edit Profile',
                        onPressed: onEditProfile,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProfileActionButton(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onPressed: onSettings,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ProfileActionButton(
                        icon: Icons.logout,
                        label: 'Logout',
                        onPressed: onLogout,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // subjects the student needs help with - feeds the AI matching
          // feature (this was previously being saved but never displayed)
          if (profile != null && profile.subjects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Subjects I Need Help With',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.subjects
                    .map((subject) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.tpRed),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            subject,
                            style: TextStyle(
                              color: AppTheme.tpRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // sessions section with the completed count and a view all link
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Sessions',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // count from the firestore count() aggregation query
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.tpRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.tpRed.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${completedCount ?? 0} completed',
                        style: TextStyle(
                          color: AppTheme.tpRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onSeeMore,
                  // opens the full sessions list with its filters
                  child: Row(
                    children: [
                      Text(
                        'View all',
                        style: TextStyle(
                          color: AppTheme.tpRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right,
                          color: AppTheme.tpRed, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: sessionsAsync.when(
              // live sessions from firestore
              data: (sessions) {
                final preview = sessions.take(2).toList();
                if (preview.isEmpty) {
                  return Text(
                    'No sessions yet - book one from a mentor profile!',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  );
                }
                return Column(
                  children: preview
                      .map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SessionCard(
                                session: s,
                                onTap: () => onSessionTap?.call(s)),
                          ))
                      .toList(),
                      // one session card per session
                );
              },
              loading: () => Center(
                  child: CircularProgressIndicator(color: AppTheme.tpRed)),
              error: (e, _) => Text(
                'Could not load sessions',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // premium subscription advert card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCardBg,
              border: Border.all(color: AppTheme.darkBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // left side, name and the perks you get
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TPMentorship',
                              style: TextStyle(
                                color: AppTheme.tpRed,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.workspace_premium,
                                color: Colors.amber, size: 18),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _premiumBullet(
                            'Priority When booking sessions as a Student.'),
                        const SizedBox(height: 4),
                        _premiumBullet(
                            'Instant Messages without needing to book'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // right side: price and upgrade link, active badge, or the
                  // cancelled message with the end-of-month date
                  if (isPremium && premiumCancelled)
                    SizedBox(
                      width: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.info_outline,
                              color: AppTheme.textSecondary, size: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Membership Cancelled',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Active until ${_formatDate(_endOfMonth(profile!.premiumCancelledAt ?? DateTime.now()))}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (isPremium)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              'ACTIVE',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _confirmCancelPremium(context, ref),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.tpRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Cancel Membership',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$2.99',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '/mo',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: onGoPremium,
                          // opens the NETS QR payment screen
                          child: Text(
                            'Upgrade >',
                            style: TextStyle(
                              color: AppTheme.tpRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // payment method card (NETS QR) - opens the premium screen
          GestureDetector(
            onTap: isPremium ? null : onGoPremium,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.darkCardBg,
                border: Border.all(color: AppTheme.darkBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // NETS logo box
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'NETS',
                        style: TextStyle(
                          color: Color(0xFF003087),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // payment details text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium
                              ? 'Premium active - paid via NETS QR'
                              : 'Payment via NETS QR Code',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cancel Anytime in your Settings',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                        Text(
                          'First time Purchase, +3 Months free!',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (!isPremium)
                    Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _premiumBullet(String text) {
  // a single bullet point line in the premium card
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
// small icon and label button used in the profile card
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _ProfileActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          // shrink the text/icon so it never overflows the button
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: AppTheme.tpRed),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.tpRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
