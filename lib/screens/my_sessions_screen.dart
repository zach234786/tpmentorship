import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/session.dart';
// the session data type
import 'package:tpmentorship/providers/data_providers.dart';
// the app's firestore providers
import 'package:tpmentorship/screens/book_session_screen.dart';
// the booking form
import 'package:tpmentorship/screens/session_detail_screen.dart';
// the single session view
import 'package:tpmentorship/services/appointment_service.dart';
// for friendlyError when an accept/reject write fails
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/widgets/session_card.dart';
// the session card widget

class MySessionsScreen extends ConsumerStatefulWidget {
// the READ (select all) part of CRUD - lists every session the logged in
// student has booked, live from Firestore
//
// an account that has signed up as a mentor can also flip to "Session
// Requests", which runs the same queries filtered on mentorId instead of
// studentId, so they can see and answer what students booked with them
//
// the status tabs use DefaultTabController + TabBar (a navigation
// structure taught in class, alongside the app's BottomNavigationBar).
// the "All" tab runs the plain select-all query and every other tab runs
// the advanced query "multiple filters on different fields"

  const MySessionsScreen({super.key});

  // one tab per status
  static const _statuses = [
    'All',
    'Pending',
    'Confirmed',
    'Completed',
    'Cancelled',
  ];

  @override
  ConsumerState<MySessionsScreen> createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends ConsumerState<MySessionsScreen> {
  bool _mentorMode = false;
  // false = sessions I booked as a student, true = requests students sent
  // me as a mentor. only reachable when the profile says isMentor

  @override
  Widget build(BuildContext context) {
    // the same gate the search screen's browse-students toggle uses
    final isMentor = ref.watch(isMentorProvider);
    // an account that never signed up as a mentor has nothing to switch to,
    // so the toggle is hidden entirely rather than shown leading nowhere
    final mentorMode = _mentorMode && isMentor;

    return DefaultTabController(
      length: MySessionsScreen._statuses.length,
      child: Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          title: Text(mentorMode ? 'Session Requests' : 'My Sessions'),
          actions: [
            if (isMentor)
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: mentorMode
                    ? 'View sessions I booked'
                    : 'View requests students sent me',
                onPressed: () => setState(() => _mentorMode = !_mentorMode),
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.tpRed,
            labelColor: AppTheme.tpRed,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: MySessionsScreen._statuses
                .map((status) => Tab(text: status))
                .toList(),
          ),
        ),
        // button to book a brand new session - booking is something you do
        // as a student, so it is hidden while reviewing incoming requests
        floatingActionButton: mentorMode
            ? null
            : FloatingActionButton(
                backgroundColor: AppTheme.tpRed,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const BookSessionScreen()),
                  );
                },
                child: const Icon(Icons.add, color: Colors.white),
              ),
        body: SafeArea(
          child: TabBarView(
            children: MySessionsScreen._statuses
                .map((status) =>
                    _SessionsTab(status: status, mentorMode: mentorMode))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _SessionsTab extends ConsumerWidget {
// the list shown inside one status tab
  const _SessionsTab({required this.status, required this.mentorMode});

  final String status;
  final bool mentorMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 'All' uses the plain select-all query, anything else uses the
    // two-field filter query. mentor mode swaps studentId for mentorId
    final sessionsAsync = mentorMode
        ? (status == 'All'
            ? ref.watch(mentorSessionsProvider)
            : ref.watch(mentorSessionsByStatusProvider(status)))
        : (status == 'All'
            ? ref.watch(mySessionsProvider)
            : ref.watch(mySessionsByStatusProvider(status)));

    return sessionsAsync.when(
      // the stream gives us loading / error / data states
      data: (sessions) {
        if (sessions.isEmpty) {
          // friendly empty state instead of a blank screen
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy,
                    color: AppTheme.textSecondary, size: 48),
                const SizedBox(height: 12),
                Text(
                  mentorMode
                      ? (status == 'All'
                          ? 'No students have booked you yet'
                          : 'No $status requests')
                      : (status == 'All'
                          ? 'No sessions booked yet'
                          : 'No $status sessions'),
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  mentorMode
                      ? 'Requests appear here when a student books you'
                      : 'Tap + to book your first session',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SessionCard(
                    session: session,
                    onTap: () {
                      // open the single session view (select one)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SessionDetailScreen(sessionId: session.id),
                        ),
                      );
                    },
                  ),
                  // a mentor looking at a request needs to know who sent it
                  // and be able to answer it, right from the list
                  if (mentorMode) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Booked by ${session.studentName.isEmpty ? 'a student' : session.studentName}',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ),
                        // explains why this request is sitting at the top
                        // of the list (see AppointmentService._sortForMentor)
                        if (session.studentIsPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.tpRed.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: TextStyle(
                                color: AppTheme.tpRed,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (session.status == 'Pending')
                      _AcceptRejectRow(session: session),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          Center(child: CircularProgressIndicator(color: AppTheme.tpRed)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load sessions.\n$e',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _AcceptRejectRow extends ConsumerStatefulWidget {
// the Accept / Reject pair under a pending request in mentor mode
  const _AcceptRejectRow({required this.session});

  final Session session;

  @override
  ConsumerState<_AcceptRejectRow> createState() => _AcceptRejectRowState();
}

class _AcceptRejectRowState extends ConsumerState<_AcceptRejectRow> {
  bool _busy = false;
  // disables both buttons while the write is in flight, so a double tap
  // cannot fire two updates for the same request

  Future<void> _setStatus(String status, String message) async {
    setState(() => _busy = true);
    try {
      // writes only the status field - see AppointmentService.updateStatus
      await ref
          .read(appointmentServiceProvider)
          .updateStatus(widget.session.id, status);
      if (!mounted) return;
      showAppSnackBar(context, message, success: true);
      // the list refreshes by itself - it is watching the stream
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, AppointmentService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _busy
                ? null
                : () => _setStatus('Cancelled', 'Request rejected'),
            child: Text('Reject',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : () => _setStatus('Confirmed', 'Session confirmed!'),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Accept'),
          ),
        ),
      ],
    );
  }
}
