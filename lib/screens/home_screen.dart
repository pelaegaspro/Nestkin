import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

import '../models/household_member_model.dart';
import '../models/household_model.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';
import '../services/chat_repository.dart';
import '../services/firestore_service.dart';
import '../services/medicine_notification_service.dart';
import '../services/points_service.dart';
import '../services/sos_service.dart';
import 'add_task_screen.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'expenses_screen.dart';
import 'household_screen.dart';
import 'household_map_screen.dart';
import 'invite_member_screen.dart';
import 'leaderboard_screen.dart';
import 'lists_screen.dart';
import 'login_screen.dart';
import 'medicine_detail_screen.dart';
import 'medicines_screen.dart';
import 'members_screen.dart';
import 'notes_grid_screen.dart';
import 'weekly_planner_screen.dart';
import '../widgets/sos_active_banner.dart';
import '../widgets/role_guard.dart';
import '../widgets/sos_confirm_dialog.dart';
import '../widgets/sos_received_banner.dart';

enum TaskFilter {
  all,
  mine,
  unassigned,
}

class HomeScreen extends StatefulWidget {
  final String householdId;
  final String? initialTaskId;

  const HomeScreen({
    super.key,
    required this.householdId,
    this.initialTaskId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fs = FirestoreService();
  final _chatRepository = ChatRepository();
  final _pointsService = PointsService();
  final _sosService = SOSService();
  final _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  TaskFilter _taskFilter = TaskFilter.all;
  bool _redirectingRemovedMember = false;
  bool _notificationHintShown = false;
  StreamSubscription<List<SOSAlertModel>>? _sosSubscription;
  String? _activeBannerKey;

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _initializeMedicineNotifications();
    _subscribeToSosAlerts();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      _subscribeToSosAlerts();
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _initializeMedicineNotifications() async {
    await MedicineNotificationService.instance.initialize(
      onOpenMedicine: (householdId, medicineId) async {
        if (!mounted) {
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicineDetailScreen(
              householdId: householdId,
              medicineId: medicineId,
            ),
          ),
        );
      },
    );
  }

  void _subscribeToSosAlerts() {
    _sosSubscription?.cancel();
    _sosSubscription = _sosService.activeAlertsStream(widget.householdId).listen(
      _handleSosAlerts,
    );
  }

  void _handleSosAlerts(List<SOSAlertModel> alerts) {
    if (!mounted) {
      return;
    }

    SOSAlertModel? selfAlert;
    SOSAlertModel? otherAlert;
    for (final alert in alerts) {
      if (alert.uid == _currentUid) {
        selfAlert = alert;
        break;
      }
      otherAlert ??= alert;
    }

    final messenger = ScaffoldMessenger.of(context);

    if (selfAlert != null) {
      final key = 'self:${selfAlert.uid}:${selfAlert.triggeredAt.seconds}';
      if (_activeBannerKey == key) {
        return;
      }
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.red.shade50,
          content: SOSActiveBanner(
            alert: selfAlert,
            onSafe: () => _resolveSos(selfAlert!),
          ),
          actions: const [SizedBox.shrink()],
        ),
      );
      _activeBannerKey = key;
      return;
    }

    if (otherAlert != null) {
      final key = 'other:${otherAlert.uid}:${otherAlert.triggeredAt.seconds}';
      if (_activeBannerKey == key) {
        return;
      }
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.red.shade50,
          content: SOSReceivedBanner(
            alert: otherAlert,
            onViewLocation: () {
              messenger.clearMaterialBanners();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseholdMapScreen(
                    householdId: widget.householdId,
                    initialFocusLat: otherAlert!.lat,
                    initialFocusLng: otherAlert.lng,
                    highlightedMemberName: otherAlert.triggeredByName,
                  ),
                ),
              );
            },
          ),
          actions: const [SizedBox.shrink()],
        ),
      );
      _activeBannerKey = key;
      return;
    }

    if (_activeBannerKey != null) {
      messenger.clearMaterialBanners();
      _activeBannerKey = null;
    }
  }

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const SOSConfirmDialog(),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final member = await _fs.getHouseholdMember(
        householdId: widget.householdId,
        userId: _currentUid,
      );
      if (member == null) {
        throw Exception('Could not load your household profile.');
      }

      await _sosService.triggerSOS(
        householdId: widget.householdId,
        member: member,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _resolveSos(SOSAlertModel alert) async {
    try {
      await _sosService.resolveSOS(
        householdId: widget.householdId,
        uid: alert.uid,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _handleRemovedFromHousehold() {
    if (_redirectingRemovedMember) {
      return;
    }

    _redirectingRemovedMember = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HouseholdScreen(
            skipAutoCheck: true,
            accessMessage: 'You no longer have access to this household.',
          ),
        ),
        (route) => false,
      );
    });
  }

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    switch (_taskFilter) {
      case TaskFilter.all:
        return tasks;
      case TaskFilter.mine:
        return tasks.where((task) => task.assignedToId == _currentUid).toList();
      case TaskFilter.unassigned:
        return tasks.where((task) => task.assignedToId == null || task.assignedToId!.isEmpty).toList();
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _taskSubtitle(TaskModel task) {
    final due = task.dueDate == null ? 'No due date' : 'Due ${_formatDate(task.dueDate!.toDate())}';
    final assigned = task.assignedToName ?? task.assignedTo?['displayName'] ?? 'Unassigned';
    return '$due - Assigned to $assigned';
  }

  Future<void> _showStatusDialog(TaskModel task) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(task.title),
        content: Text(
          task.isComplete ? 'Mark this task as incomplete?' : 'Mark this task as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final willComplete = !task.isComplete;
                await _pointsService.toggleTaskCompletion(
                  householdId: widget.householdId,
                  task: task,
                  actingUserId: _currentUid,
                );
                if (willComplete) {
                  _confettiController.play();
                }
              } catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: Text(task.isComplete ? 'Undo' : 'Complete'),
          ),
        ],
      ),
    );
  }

  void _openFeature(String value) {
    final route = switch (value) {
      'map' => MaterialPageRoute(
          builder: (_) => HouseholdMapScreen(householdId: widget.householdId),
        ),
      'calendar' => MaterialPageRoute(
          builder: (_) => CalendarScreen(householdId: widget.householdId),
        ),
      'lists' => MaterialPageRoute(
          builder: (_) => ListsScreen(householdId: widget.householdId),
        ),
      'expenses' => MaterialPageRoute(
          builder: (_) => ExpensesScreen(householdId: widget.householdId),
        ),
      'meals' => MaterialPageRoute(
          builder: (_) => WeeklyPlannerScreen(householdId: widget.householdId),
        ),
      'medicines' => MaterialPageRoute(
          builder: (_) => MedicinesScreen(householdId: widget.householdId),
        ),
      'notes' => MaterialPageRoute(
          builder: (_) => NotesGridScreen(householdId: widget.householdId),
        ),
      'leaderboard' => MaterialPageRoute(
          builder: (_) => LeaderboardScreen(householdId: widget.householdId),
        ),
      _ => null,
    };

    if (route != null) {
      Navigator.push(context, route);
    }
  }

  @override
  void dispose() {
    _sosSubscription?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _showNotificationHintIfNeeded(List<TaskModel> tasks) {
    if (_notificationHintShown || widget.initialTaskId == null) {
      return;
    }

    TaskModel? highlightedTask;
    for (final task in tasks) {
      if (task.id == widget.initialTaskId) {
        highlightedTask = task;
        break;
      }
    }

    if (highlightedTask == null) {
      return;
    }

    final highlightedTaskTitle = highlightedTask.title;
    _notificationHintShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opened task "$highlightedTaskTitle" from your notification.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<HouseholdModel?>(
      stream: _fs.householdStream(widget.householdId),
      builder: (context, householdSnapshot) {
        if (householdSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final household = householdSnapshot.data;
        if (household == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Household')),
            body: const Center(
              child: Text('This household is no longer available.'),
            ),
          );
        }

        return StreamBuilder<List<HouseholdMemberModel>>(
          stream: _fs.householdMembersStream(widget.householdId),
          builder: (context, membersSnapshot) {
            if (membersSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (membersSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('Could not load household members right now.')),
              );
            }

            final members = [...(membersSnapshot.data ?? const <HouseholdMemberModel>[])];
            final isCurrentMember = members.any((member) => member.userId == _currentUid);
            final isListedOnHousehold = household.members.contains(_currentUid);
            if (!isCurrentMember && !isListedOnHousehold) {
              _handleRemovedFromHousehold();
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            members.sort((a, b) {
              if (a.role != b.role) {
                return a.role == 'admin' ? -1 : 1;
              }

              final aName = (a.user['displayName'] ?? a.user['phoneNumber'] ?? 'User').toString();
              final bName = (b.user['displayName'] ?? b.user['phoneNumber'] ?? 'User').toString();
              return aName.toLowerCase().compareTo(bName.toLowerCase());
            });

            return StreamBuilder<List<TaskModel>>(
              stream: _fs.tasksStream(widget.householdId),
              builder: (context, tasksSnapshot) {
                if (tasksSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final tasks = tasksSnapshot.data ?? [];
                final filteredTasks = _applyFilter(tasks);
                final totalCount = tasks.length;
                final completedCount = tasks.where((task) => task.isComplete).length;
                final pendingCount = totalCount - completedCount;

                _showNotificationHintIfNeeded(tasks);

                return Scaffold(
                  appBar: AppBar(
                    title: Text(household.name),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.people_outline),
                        tooltip: 'Members',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MembersScreen(householdId: widget.householdId),
                          ),
                        ),
                      ),
                      RoleGuard(
                        householdId: widget.householdId,
                        userId: _currentUid,
                        allow: (role) => role.canManageHousehold,
                        child: IconButton(
                          icon: const Icon(Icons.person_add_outlined),
                          tooltip: 'Invite member',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InviteMemberScreen(householdId: widget.householdId),
                            ),
                          ),
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: _chatRepository.unreadCountStream(
                          householdId: widget.householdId,
                          currentUid: _currentUid,
                        ),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          return IconButton(
                            tooltip: 'Chat',
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(householdId: widget.householdId),
                              ),
                            ),
                            icon: Badge(
                              isLabelVisible: unreadCount > 0,
                              label: Text('$unreadCount'),
                              child: const Icon(Icons.chat_bubble_outline),
                            ),
                          );
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: _openFeature,
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'calendar', child: Text('Calendar')),
                          PopupMenuItem(value: 'expenses', child: Text('Expenses')),
                          PopupMenuItem(value: 'lists', child: Text('Shopping Lists')),
                          PopupMenuItem(value: 'map', child: Text('Family Map')),
                          PopupMenuItem(value: 'meals', child: Text('Meal Planner')),
                          PopupMenuItem(value: 'medicines', child: Text('Medicines')),
                          PopupMenuItem(value: 'notes', child: Text('Notes')),
                          PopupMenuItem(value: 'leaderboard', child: Text('Leaderboard')),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout),
                        tooltip: 'Sign out',
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                  floatingActionButton: SizedBox(
                    width: 164,
                    height: 84,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: RoleGuard(
                            householdId: widget.householdId,
                            userId: _currentUid,
                            allow: (role) => role.canAssignTasks,
                            child: FloatingActionButton(
                              heroTag: 'add_task_fab',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddTaskScreen(householdId: widget.householdId),
                                ),
                              ),
                              child: const Icon(Icons.add),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: FloatingActionButton.extended(
                            heroTag: 'sos_fab',
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            onPressed: _triggerSos,
                            icon: const Icon(Icons.warning_amber_rounded),
                            label: const Text('SOS'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              household.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Invite code: ${household.inviteCode}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _MemberAvatarRow(members: members),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _TaskSummaryCard(
                        totalCount: totalCount,
                        completedCount: completedCount,
                        pendingCount: pendingCount,
                      ),
                      const SizedBox(height: 20),
                      _TaskFilterBar(
                        selected: _taskFilter,
                        onChanged: (filter) {
                          setState(() => _taskFilter = filter);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (filteredTasks.isEmpty)
                        _EmptyTaskState(filter: _taskFilter)
                      else
                        ...filteredTasks.map(
                          (task) => Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: widget.initialTaskId == task.id
                                ? theme.colorScheme.secondaryContainer
                                : null,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: task.isComplete ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (task.description != null && task.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Text(task.description!),
                                      ),
                                    Text(_taskSubtitle(task)),
                                    const SizedBox(height: 4),
                                    Text('${task.points} points'),
                                  ],
                                ),
                              ),
                              trailing: Chip(
                                label: Text(task.isComplete ? 'Completed' : 'Pending'),
                                backgroundColor: task.isComplete
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                              ),
                              onTap: () => _showStatusDialog(task),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MemberAvatarRow extends StatelessWidget {
  final List<HouseholdMemberModel> members;

  const _MemberAvatarRow({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'No members yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final visibleMembers = members.take(5).toList();
    final overflowCount = members.length - visibleMembers.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...visibleMembers.map(
          (member) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MemberAvatar(member: member),
              const SizedBox(height: 6),
              SizedBox(
                width: 58,
                child: Text(
                  (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'User').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
        if (overflowCount > 0)
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              '+$overflowCount',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final HouseholdMemberModel member;

  const _MemberAvatar({required this.member});

  @override
  Widget build(BuildContext context) {
    final photoUrl = member.user['photoUrl']?.toString();
    final fallback = (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'User').toString();
    final initials = fallback
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return CircleAvatar(
      radius: 24,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl == null || photoUrl.isEmpty
          ? Text(initials.isEmpty ? 'U' : initials)
          : null,
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  final int totalCount;
  final int completedCount;
  final int pendingCount;

  const _TaskSummaryCard({
    required this.totalCount,
    required this.completedCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryValue(
            label: 'Total',
            value: totalCount,
            color: Theme.of(context).colorScheme.primary,
          ),
          _SummaryValue(
            label: 'Completed',
            value: completedCount,
            color: Colors.green.shade700,
          ),
          _SummaryValue(
            label: 'Pending',
            value: pendingCount,
            color: Colors.orange.shade800,
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _SummaryValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}

class _TaskFilterBar extends StatelessWidget {
  final TaskFilter selected;
  final ValueChanged<TaskFilter> onChanged;

  const _TaskFilterBar({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: selected == TaskFilter.all,
          onSelected: (_) => onChanged(TaskFilter.all),
        ),
        ChoiceChip(
          label: const Text('Mine'),
          selected: selected == TaskFilter.mine,
          onSelected: (_) => onChanged(TaskFilter.mine),
        ),
        ChoiceChip(
          label: const Text('Unassigned'),
          selected: selected == TaskFilter.unassigned,
          onSelected: (_) => onChanged(TaskFilter.unassigned),
        ),
      ],
    );
  }
}

class _EmptyTaskState extends StatelessWidget {
  final TaskFilter filter;

  const _EmptyTaskState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      TaskFilter.all => 'No tasks yet. Tap + to add the first one.',
      TaskFilter.mine => 'Nothing is assigned to you right now.',
      TaskFilter.unassigned => 'There are no unassigned tasks right now.',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
