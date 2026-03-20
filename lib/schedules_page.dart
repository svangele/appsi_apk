import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SchedulesPage extends StatefulWidget {
  const SchedulesPage({super.key});

  @override
  State<SchedulesPage> createState() => _SchedulesPageState();
}

class _SchedulesPageState extends State<SchedulesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _schedules = [];

  // Form State
  final _nameController = TextEditingController();
  final _zoneController = TextEditingController();
  List<Map<String, dynamic>> _currentRules = [];

  // Rules Quick-Define state
  final Set<int> _selectedDays = {};
  TimeOfDay _tempIn = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _tempOut = const TimeOfDay(hour: 18, minute: 0);
  int _tempTolerance = 10;

  final List<String> _daysOfWeek = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('schedules').select().order('name');
      setState(() {
        _schedules = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching schedules: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addRuleGroup() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona al menos un día.')),
      );
      return;
    }

    setState(() {
      for (int day in _selectedDays) {
        // Add Entry
        _currentRules.add({
          'day': day,
          'type': 'ENTRADA',
          'time': '${_tempIn.hour.toString().padLeft(2, '0')}:${_tempIn.minute.toString().padLeft(2, '0')}:00',
          'tol': _tempTolerance,
        });
        // Add Exit
        _currentRules.add({
          'day': day,
          'type': 'SALIDA',
          'time': '${_tempOut.hour.toString().padLeft(2, '0')}:${_tempOut.minute.toString().padLeft(2, '0')}:00',
          'tol': 0,
        });
      }

      // De-duplicate if same day/type exists? For now just add.
      // Sort rules
      _currentRules.sort((a, b) {
        int dayCmp = a['day'].compareTo(b['day']);
        if (dayCmp != 0) return dayCmp;
        return a['time'].compareTo(b['time']);
      });

      _selectedDays.clear();
    });
  }

  void _removeRule(int index) {
    setState(() {
      _currentRules.removeAt(index);
    });
  }

  Future<void> _saveSchedule() async {
    if (_nameController.text.isEmpty || _currentRules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre y al menos una regla.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.from('schedules').insert({
        'name': _nameController.text.trim(),
        'zone': _zoneController.text.trim(),
        'rules': _currentRules,
      });

      _nameController.clear();
      _zoneController.clear();
      setState(() {
        _currentRules = [];
        _isLoading = false;
      });
      _fetchSchedules();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horario maestro creado con éxito ✅')),
        );
      }
    } catch (e) {
      debugPrint('Error saving schedule: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Future<void> _deleteSchedule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Horario'),
        content: const Text('¿Estás seguro de eliminar este horario maestro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR')
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('schedules').delete().eq('id', id);
        _fetchSchedules();
      } catch (e) {
        debugPrint('Error deleting schedule: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configuración Rápida de Horarios', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildForm(theme, isDesktop),
                const SizedBox(height: 40),
                const Text(
                  'Catálogo de Horarios:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildScheduleList(theme, isDesktop),
              ],
            ),
          ),
    );
  }

  Widget _buildForm(ThemeData theme, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. Definir Identificación:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del horario (ej. Corporativo)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _zoneController,
                  decoration: const InputDecoration(
                    labelText: 'Zona / Ubicación',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('2. Configurar Jornada (Creación Rápida):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildQuickDefineRow(theme, isDesktop),
          const SizedBox(height: 32),
          if (_currentRules.isNotEmpty) ...[
            const Text('3. Revisar Reglas Generadas:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _currentRules.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final rule = _currentRules[index];
                  final dayName = _daysOfWeek[rule['day']];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      child: Text(dayName[0], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ),
                    title: Text('$dayName - ${rule['type']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Hora: ${rule['time'].toString().substring(0, 5)} ${rule['type'] == 'ENTRADA' ? '(Tolerancia: ${rule['tol']}m)' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => _removeRule(index),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saveSchedule,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('CONFIRMAR Y GUARDAR TODO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF323B94),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDefineRow(ThemeData theme, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selecciona uno o varios días:', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(7, (i) {
            final active = _selectedDays.contains(i);
            return FilterChip(
              label: Text(_daysOfWeek[i]),
              selected: active,
              onSelected: (selected) {
                setState(() {
                  if (selected) _selectedDays.add(i);
                  else _selectedDays.remove(i);
                });
              },
              selectedColor: theme.colorScheme.primary.withOpacity(0.2),
              checkmarkColor: theme.colorScheme.primary,
            );
          }),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 140,
              child: _buildTimePickerTile('ENTRADA', _tempIn, (t) => setState(() => _tempIn = t)),
            ),
            SizedBox(
              width: 140,
              child: _buildTimePickerTile('SALIDA', _tempOut, (t) => setState(() => _tempOut = t)),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                value: _tempTolerance,
                decoration: const InputDecoration(labelText: 'Tolerancia', labelStyle: TextStyle(fontSize: 12), border: OutlineInputBorder()),
                items: [0, 5, 10, 15, 20, 30].map((t) => DropdownMenuItem(value: t, child: Text('$t min'))).toList(),
                onChanged: (v) => setState(() => _tempTolerance = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addRuleGroup,
            icon: const Icon(Icons.add_task),
            label: const Text('VINCULAR JORNADA A DÍAS SELECCIONADOS', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerTile(String label, TimeOfDay time, Function(TimeOfDay) OnChanged) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(
          context: context, 
          initialTime: time,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );
        if (t != null) OnChanged(t);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList(ThemeData theme, bool isDesktop) {
    if (_schedules.isEmpty) {
      return const Center(child: Text('No hay horarios registrados.'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isDesktop ? 1.3 : 1.2,
      ),
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        final sched = _schedules[index];
        final List<dynamic> rules = sched['rules'] ?? [];
        
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        sched['name'], 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      onPressed: () => _deleteSchedule(sched['id']),
                    ),
                  ],
                ),
                Text(
                  'Zona: ${sched['zone'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: rules.length,
                    itemBuilder: (ctx, i) {
                      final r = rules[i];
                      final dayLabel = _daysOfWeek[r['day']].substring(0, 3);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 35,
                              child: Text(
                                dayLabel, 
                                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 12)
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${r['type'] == 'ENTRADA' ? 'Ent' : 'Sal'}: ${r['time'].toString().substring(0, 5)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            if (r['type'] == 'ENTRADA')
                              Text(' (+${r['tol']}m)', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
