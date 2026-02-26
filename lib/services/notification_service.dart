import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final client = Supabase.instance.client;

  /// Stream de TODAS las notificaciones para filtrado client-side en tiempo real
  static Stream<List<Map<String, dynamic>>> get allNotificationsStream {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  /// Obtiene todas las notificaciones recientes
  static Future<List<Map<String, dynamic>>> fetchRecent() async {
    final response = await client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Marca una notificación como leída
  static Future<void> markAsRead(String id) async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
  }

  /// Marca todas las notificaciones como leídas
  static Future<void> markAllAsRead() async {
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
  }

  /// Elimina una notificación
  static Future<void> deleteNotification(String id) async {
    await client.from('notifications').delete().eq('id', id);
  }

  /// Envía una nueva notificación
  static Future<void> send({
    required String title,
    required String message,
    String type = 'incidencia_alert',
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    await client.from('notifications').insert({
      'title': title,
      'message': message,
      'type': type,
      'user_id': userId,
      'metadata': metadata ?? {},
    });
  }
}
