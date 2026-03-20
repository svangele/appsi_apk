import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_web_plugins/url_strategy.dart';
// Note: In a real project, we might need a web-specific save utility for CSV.
// For now, we'll implement a simple web download trigger if on web.
import 'package:flutter/foundation.dart' show kIsWeb;
// We'll use a dynamic approach to avoid mobile compilation errors
import 'dart:js' as js;

class AttendanceAdminPage extends StatefulWidget {
  final String role;
  final Map<String, dynamic> permissions;
  const AttendanceAdminPage({super.key, required this.role, required this.permissions});

  @override
  State<AttendanceAdminPage> createState() => _AttendanceAdminPageState();
}

class _AttendanceAdminPageState extends State<AttendanceAdminPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];
  final _supabase = Supabase.instance.client;
  String _searchQuery = '';
  DateTime? _selectedDate;
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
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos administrativos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = _allRecords.where((record) {
        final matchesName = (record['profiles']?['full_name'] ?? '')
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        
        bool matchesDate = true;
        if (_selectedDate != null) {
          final recordDate = record['date'];
          matchesDate = recordDate == DateFormat('yyyy-MM-dd').format(_selectedDate!);
        }
        
        return matchesName && matchesDate;
      }).toList();
    });
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

  void _exportToCSV() {
    if (_filteredRecords.isEmpty) return;

    List<List<dynamic>> rows = [];
    // Cabecera
    rows.add([
      'Empleado',
      'Fecha',
      'Entrada',
      'Salida',
      'Ubicación Entrada (Lat, Lng)',
      'Ubicación Salida (Lat, Lng)',
      'Validado'
    ]);

    for (var rec in _filteredRecords) {
      rows.add([
        rec['profiles']?['full_name'] ?? 'N/A',
        rec['date'],
        rec['check_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(rec['check_in'])) : '--:--',
        rec['check_out'] != null ? DateFormat('HH:mm').format(DateTime.parse(rec['check_out'])) : '--:--',
        '${rec['lat']}, ${rec['lng']}',
        '${rec['lat_out'] ?? ''}, ${rec['lng_out'] ?? ''}',
        rec['validated'] == true ? 'SÍ' : 'NO'
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    
    if (kIsWeb) {
      // Usar JS interop para disparar la descarga en el navegador de forma segura
      final String fileName = "asistencia_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv";
      final String blobUrl = js.context.callMethod('URL', ['createObjectURL', js.JsObject(js.context['Blob'], [[csvData], js.JsObject.jsify({'type': 'text/csv'})])]);
      final anchor = js.context.callMethod('document', ['createElement', 'a']);
      js.context.callMethod(anchor, ['setAttribute', 'href', blobUrl]);
      js.context.callMethod(anchor, ['setAttribute', 'download', fileName]);
      js.context.callMethod(anchor, ['click']);
    } else {
      debugPrint('Exportación no implementada para plataformas no-web.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(theme),
          _buildFilters(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildList(theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportToCSV,
        backgroundColor: const Color(0xFFB1CB34),
        icon: const Icon(Icons.download_rounded),
        label: const Text('EXPORTAR CSV', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.admin_panel_settings, color: Colors.white),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestión de Asistencia',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Panel de administrador',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              _searchQuery = val;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nombre...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _applyFilters();
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_selectedDate == null 
                      ? 'Filtrar por fecha' 
                      : DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                ),
              ),
              if (_selectedDate != null)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    if (_filteredRecords.isEmpty) {
      return const Center(child: Text('No se encontraron registros.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final rec = _filteredRecords[index];
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
