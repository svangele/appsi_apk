import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'schedules_page.dart';

class AttendanceAdminPage extends StatefulWidget {
  final String role;
  final Map<String, dynamic> permissions;
  final String? initialSearchQuery;
  const AttendanceAdminPage({super.key, required this.role, required this.permissions, this.initialSearchQuery});

  @override
  State<AttendanceAdminPage> createState() => _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends State<AttendanceAdminPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRecords = [];
  final _supabase = Supabase.instance.client;
  bool get _isAdmin => widget.role == 'admin' || widget.role == 'superadmin';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Obtener todos los registros uniendo con perfiles para ver nombres y horarios
      final data = await _supabase
          .from('attendance')
          .select('*, profiles:colaborador_id(full_name, work_start_time, work_end_time, schedules(name, rules))')
          .order('date', ascending: false);
      
      if (mounted) {
        setState(() {
          _allRecords = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos administrativos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMap(num? lat, num? lng) async {
    if (lat == null || lng == null || (lat == 0 && lng == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no disponible')),
      );
      return;
    }
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ExpansionTile(
              initiallyExpanded: true,
              iconColor: theme.colorScheme.primary,
              collapsedIconColor: Colors.grey,
              title: Text('Horarios', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
              children: [
                const SchedulesPage(),
              ],
            ),
            const Divider(height: 1),
            ExpansionTile(
              initiallyExpanded: false,
              iconColor: theme.colorScheme.primary,
              collapsedIconColor: Colors.grey,
              title: Text('Registros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
              children: [
                _isLoading
                    ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                    : _buildList(theme),
              ],
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildList(ThemeData theme) {
    if (_allRecords.isEmpty) {
      return const Center(child: Text('No se encontraron registros.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _allRecords.length,
      itemBuilder: (context, index) {
        final rec = _allRecords[index];
          final name = rec['profiles']?['full_name'] ?? 'Usuario Desconocido';
        final dateStr = rec['date'];
        final recordDate = DateTime.parse(dateStr);
        final checkInStr = rec['check_in'];
        
        // Robustez: Manejar respuesta de Supabase (Mapa o Lista)
        final schedData = rec['profiles']?['schedules'];
        final Map<String, dynamic>? sched = (schedData is List && schedData.isNotEmpty) 
            ? schedData[0] as Map<String, dynamic> 
            : (schedData is Map<String, dynamic> ? schedData : null);

        final List<dynamic> rules = (sched != null && sched['rules'] != null) ? sched['rules'] : [];
        
        String statusText = 'Pendiente';
        Color statusColor = Colors.grey;
        
        // dayOfWeek: 1 (Mon) to 7 (Sun) in Dart. Convert to 0-6 (0=Sun, 1=Mon...).
        final dayIndex = recordDate.weekday % 7;

        // Buscar regla de ENTRADA para este día
        final entryRule = rules.firstWhere(
          (r) => r['day'] == dayIndex && r['type'] == 'ENTRADA',
          orElse: () => null,
        );

        if (checkInStr != null) {
          final checkInLocal = DateTime.parse(checkInStr).toLocal();
          
          if (entryRule != null) {
            final workStartStr = entryRule['time'] ?? '09:00:00';
            final tolerance = entryRule['tol'] ?? 10;
            
            final parts = workStartStr.split(':');
            final workStart = DateTime(
              recordDate.year,
              recordDate.month,
              recordDate.day,
              int.parse(parts[0]),
              int.parse(parts[1]),
            );

            if (checkInLocal.isAfter(workStart.add(Duration(minutes: tolerance)))) {
              statusText = 'RETARDO';
              statusColor = Colors.orange;
            } else {
              statusText = 'A TIEMPO';
              statusColor = Colors.green;
            }
          } else {
            // Sin regla específica, marcamos como VALIDADO
            statusText = 'VALIDADO';
            statusColor = theme.colorScheme.primary;
          }
        } else {
          // Si es un día pasado y no hay check_in, es FALTA
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          if (recordDate.isBefore(today)) {
            statusText = 'FALTA';
            statusColor = Colors.red;
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Text(
                name[0].toUpperCase(), 
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Text(DateFormat('EEEE, dd MMMM yyyy', 'es_MX').format(recordDate)),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildAdminInfoRow(
                      'Entrada', 
                      rec['check_in'], 
                      rec['lat'], 
                      rec['lng'], 
                      theme,
                      onEdit: (newTime) => _updateAttendanceTime(rec['id'], 'check_in', newTime),
                    ),
                    const Divider(),
                    _buildAdminInfoRow(
                      'Salida', 
                      rec['check_out'], 
                      rec['lat_out'], 
                      rec['lng_out'], 
                      theme, 
                      isOut: true,
                      onEdit: (newTime) => _updateAttendanceTime(rec['id'], 'check_out', newTime),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rec['validated'] == true ? 'VALIDADO ✅' : 'PENDIENTE ⏳',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: rec['validated'] == true ? Colors.green : Colors.orange,
                          ),
                        ),
                        if (rec['validated'] != true)
                          TextButton(
                            onPressed: () async {
                              await _supabase.from('attendance').update({'validated': true}).eq('id', rec['id']);
                              _fetchData();
                            },
                            child: const Text('VALIDAR AHORA'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPhotoSection(rec['photo_url'], rec['photo_out_url']),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoSection(String? entryUrl, String? exitUrl) {
    if (entryUrl == null && exitUrl == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Validación Visual:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Wrap( // Wrap es mejor que Row+Expanded para evitar el estiramiento en pantallas grandes
          spacing: 20,
          runSpacing: 16,
          children: [
            if (entryUrl != null)
              _buildImageCard('Entrada', entryUrl),
            if (exitUrl != null)
              _buildImageCard('Salida', exitUrl),
          ],
        ),
      ],
    );
  }

  Widget _buildImageCard(String label, String url) {
    return SizedBox(
      width: 180, // Tamaño fijo controlado para evitar "exageración"
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              url,
              height: 180,
              width: 180,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                width: 180,
                color: Colors.grey[100],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAdminInfoRow(String label, String? timeStr, num? lat, num? lng, ThemeData theme, {bool isOut = false, Function(DateTime)? onEdit}) {
    final hasTime = timeStr != null;
    final time = hasTime ? DateTime.parse(timeStr).toLocal() : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    hasTime ? DateFormat('HH:mm').format(time!) : '--:--',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (hasTime && _isAdmin && onEdit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () async {
                      final newTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(time!),
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), // Forzar 24h
                            child: child!,
                          );
                        },
                      );
                      if (newTime != null) {
                        final updated = DateTime(
                          time.year,
                          time.month,
                          time.day,
                          newTime.hour,
                          newTime.minute,
                        );
                        onEdit(updated);
                      }
                    },
                    child: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                  ),
                ),
            ],
          ),
        ),
        if (lat != null && lng != null && lat != 0)
          TextButton.icon(
            onPressed: () => _openMap(lat, lng),
            icon: Icon(Icons.map, size: 16, color: isOut ? Colors.orange : theme.colorScheme.primary),
            label: Text('VER MAPA', style: TextStyle(color: isOut ? Colors.orange : theme.colorScheme.primary)),
          )
        else
          const Text('Sin GPS', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Future<void> _updateAttendanceTime(String recordId, String column, DateTime newTime) async {
    try {
      setState(() => _isLoading = true);
      // Supabase: enviar ISO con offset local para que se guarde correctamente
      await _supabase.from('attendance').update({
        column: newTime.toUtc().toIso8601String(),
        'validated': true,
      }).eq('id', recordId);
      
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro actualizado correctamente ✅')),
        );
      }
    } catch (e) {
      debugPrint('Error al actualizar tiempo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
