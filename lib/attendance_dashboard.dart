import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'widgets/page_header.dart';

class AttendanceDashboard extends StatefulWidget {
  const AttendanceDashboard({super.key});

  @override
  State<AttendanceDashboard> createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _allRecords = [];
  String _period = 'Mes'; // 'Quincena' o 'Mes'

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final days = _period == 'Mes' ? 30 : 15;
      final startDate = now.subtract(Duration(days: days));

      final response = await _supabase
          .from('attendance')
          .select('*, profiles:colaborador_id(full_name, schedules(rules, name))')
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .order('date', ascending: false);

      setState(() {
        _allRecords = response as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _calculateStats();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Resumen de Puntualidad',
            subtitle: 'Métricas y desempeño del personal',
            trailing: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPeriodButton('Quincena'),
                  _buildPeriodButton('Mes'),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(stats, theme),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildTopLates(stats['lates_ranking'])),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: _buildReliabilitySemaphore(stats['reliability'])),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPeriodButton(String label) {
    final active = _period == label;
    return GestureDetector(
      onTap: () {
        if (!active) {
          setState(() {
            _period = label;
            _fetchStats();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF344092) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats, ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 140, // Ancho mínimo aproximado para que quepan 2 o 3 por fila según el espacio
          child: _buildStatCard('A TIEMPO', stats['on_time'].toString(), Icons.check_circle, Colors.green),
        ),
        SizedBox(
          width: 140,
          child: _buildStatCard('RETARDOS', stats['lates'].toString(), Icons.warning_rounded, Colors.orange),
        ),
        SizedBox(
          width: 140,
          child: _buildStatCard('FALTAS', stats['misses'].toString(), Icons.error_rounded, Colors.red),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLates(List<dynamic> ranking) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ranking de Retardos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (ranking.isEmpty)
            const Text('No hay retardos registrados.', style: TextStyle(color: Colors.grey))
          else
            Column(
              children: ranking.map((item) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange[50],
                    child: Text(
                      '${item['count']}',
                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_period == 'Mes' ? 'En los últimos 30 días' : 'En la última quincena'),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReliabilitySemaphore(Map<String, int> reliability) {
    final total = reliability.values.fold(0, (a, b) => a + b);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Semáforo de Fiabilidad',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildSemaphoreItem('EXCELENTE (0 Retardos)', reliability['green'] ?? 0, total, Colors.green),
          const SizedBox(height: 12),
          _buildSemaphoreItem('REGULAR (1-2 Retardos)', reliability['yellow'] ?? 0, total, Colors.orange),
          const SizedBox(height: 12),
          _buildSemaphoreItem('CRÍTICO (3+ Retardos)', reliability['red'] ?? 0, total, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSemaphoreItem(String label, int count, int total, Color color) {
    final percent = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: color.withOpacity(0.1),
          color: color,
          borderRadius: BorderRadius.circular(10),
          minHeight: 8,
        ),
      ],
    );
  }

  Map<String, dynamic> _calculateStats() {
    int onTime = 0;
    int lates = 0;
    int misses = 0;
    Map<String, int> userLates = {};
    Map<String, int> userReliabilityStatus = {}; // colaborador_id -> lateCount

    for (var rec in _allRecords) {
      try {
        final profile = rec['profiles'];
        final String name = profile?['full_name']?.toString() ?? 'Usuario';
        final String? colaboradorId = rec['colaborador_id']?.toString();
        if (colaboradorId == null) continue;

        final String? dateStr = rec['date']?.toString();
        if (dateStr == null) {
          misses++; // Si no hay fecha, algo está mal, pero contamos como falta?
          continue;
        }

        final recordDate = DateTime.parse(dateStr);
        final String? checkInStr = rec['check_in']?.toString();
        
        // Robustez: Supabase puede devolver un Mapa o una Lista de un solo elemento para un join FK
        final schedData = profile?['schedules'];
        final Map<String, dynamic>? sched = (schedData is List && schedData.isNotEmpty) 
            ? schedData[0] as Map<String, dynamic> 
            : (schedData is Map<String, dynamic> ? schedData : null);

        final List<dynamic> rules = (sched != null && sched['rules'] != null) ? sched['rules'] : [];
        
        final dayIndex = recordDate.weekday % 7;
        final entryRule = rules.firstWhere(
          (r) => r['day'] == dayIndex && r['type'] == 'ENTRADA',
          orElse: () => null,
        );

        if (checkInStr != null) {
          final checkInLocal = DateTime.parse(checkInStr).toLocal();
          if (entryRule != null) {
            final String workStartStr = entryRule['time']?.toString() ?? '09:00:00';
            final int tolerance = int.tryParse(entryRule['tol']?.toString() ?? '10') ?? 10;
            final parts = workStartStr.split(':');
            
            // Re-valida el formato HH:mm:ss
            if (parts.length >= 2) {
              final workStart = DateTime(
                recordDate.year,
                recordDate.month,
                recordDate.day,
                int.parse(parts[0]),
                int.parse(parts[1]),
              ).add(Duration(minutes: tolerance));

              if (checkInLocal.isAfter(workStart)) {
                lates++;
                userLates[name] = (userLates[name] ?? 0) + 1;
                userReliabilityStatus[colaboradorId] = (userReliabilityStatus[colaboradorId] ?? 0) + 1;
              } else {
                onTime++;
                userReliabilityStatus[colaboradorId] = (userReliabilityStatus[colaboradorId] ?? 0);
              }
            } else {
              // Si la regla está mal formada, contamos como "a tiempo" para no penalizar
              onTime++;
              userReliabilityStatus[colaboradorId] = (userReliabilityStatus[colaboradorId] ?? 0);
            }
          } else {
            onTime++; // Sin regla, asumimos a tiempo
            userReliabilityStatus[colaboradorId] = (userReliabilityStatus[colaboradorId] ?? 0);
          }
        } else {
          misses++;
          userReliabilityStatus[colaboradorId] = (userReliabilityStatus[colaboradorId] ?? 0) + 1;
        }
      } catch (e) {
        debugPrint('Error procesando un registro de asistencia: $e');
      }
    }

    // Ranking de retardos (Top 5)
    var ranking = userLates.entries
      .map((e) => {'name': e.key, 'count': e.value})
      .toList();
    ranking.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Semáforo de confiabilidad (Basado en usuarios únicos)
    int green = 0, yellow = 0, red = 0;
    userReliabilityStatus.forEach((cid, count) {
      if (count == 0) green++;
      else if (count <= 2) yellow++;
      else red++;
    });

    return {
      'on_time': onTime,
      'lates': lates,
      'misses': misses,
      'lates_ranking': ranking.take(5).toList(),
      'reliability': {'green': green, 'yellow': yellow, 'red': red},
    };
  }
}
