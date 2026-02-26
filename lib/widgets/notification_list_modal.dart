import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationListModal extends StatefulWidget {
  final String role;
  final Map<String, dynamic> permissions;
  final String currentUserId;

  const NotificationListModal({
    super.key,
    required this.role,
    required this.permissions,
    required this.currentUserId,
  });

  @override
  State<NotificationListModal> createState() => _NotificationListModalState();
}

class _NotificationListModalState extends State<NotificationListModal> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final data = await NotificationService.fetchRecent();
      setState(() {
        // Filter notifications based on role, permissions, and user
        _notifications = data.where((n) {
          final type = n['type'] as String? ?? '';
          if (type == 'collaborator_alert' || type == 'status_sys_alert') {
            return widget.role == 'admin' && widget.permissions['show_users'] == true;
          }
          if (type == 'incidencia_status') {
            return n['user_id'] == widget.currentUserId;
          }
          return true;
        }).toList()
          ..sort((a, b) {
            // Unread (PENDIENTES) first
            final aRead = a['is_read'] == true ? 1 : 0;
            final bRead = b['is_read'] == true ? 1 : 0;
            if (aRead != bRead) return aRead.compareTo(bRead);
            // Then by newest first
            return (b['created_at'] as String).compareTo(a['created_at'] as String);
          });
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notificaciones',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await NotificationService.markAllAsRead();
                    _loadNotifications();
                  },
                  child: const Text('Marcar todas como leídas'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No tienes notificaciones',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isUnread = !(notification['is_read'] ?? true);
                          final createdAt = DateTime.parse(notification['created_at']);

                          return Card(
                            elevation: 0,
                            color: isUnread ? theme.colorScheme.primary.withOpacity(0.05) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isUnread ? theme.colorScheme.primary.withOpacity(0.2) : Colors.grey[200]!,
                              ),
                            ),
                            child: ListTile(
                              onTap: () async {
                                if (isUnread) {
                                  await NotificationService.markAsRead(notification['id']);
                                  _loadNotifications();
                                }
                              },
                              leading: CircleAvatar(
                                backgroundColor: isUnread ? theme.colorScheme.primary : Colors.grey[200],
                                child: Icon(
                                  Icons.badge_outlined,
                                  color: isUnread ? Colors.white : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                notification['title'],
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification['message']),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: isUnread
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
