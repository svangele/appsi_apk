import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EventFormDialog extends StatefulWidget {
  const EventFormDialog({super.key});

  @override
  State<EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supabase = Supabase.instance.client;

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _endTime = TimeOfDay.now().replacing(
    hour: (TimeOfDay.now().hour + 1) % 24,
  );

  bool _isPublic = true;
  List<Map<String, dynamic>> _profiles = [];
  final List<String> _selectedUserIds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email')
          .neq('id', currentUserId ?? '')
          .order('full_name');
      
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('Usuario no autenticado');

      final startDateTime = DateTime(
        _startDate.year, _startDate.month, _startDate.day,
        _startTime.hour, _startTime.minute,
      );
      final endDateTime = DateTime(
        _endDate.year, _endDate.month, _endDate.day,
        _endTime.hour, _endTime.minute,
      );

      if (endDateTime.isBefore(startDateTime)) {
        throw Exception('La fecha de fin no puede ser anterior al inicio');
      }

      // Insert event
      final eventResponse = await _supabase.from('events').insert({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'start_time': startDateTime.toUtc().toIso8601String(),
        'end_time': endDateTime.toUtc().toIso8601String(),
        'creator_id': currentUserId,
        'is_public': _isPublic,
      }).select().single();

      final eventId = eventResponse['id'];

      // Insert invitations if private
      if (!_isPublic && _selectedUserIds.isNotEmpty) {
        final invitations = _selectedUserIds.map((userId) => {
          'event_id': eventId,
          'user_id': userId,
          'status': 'pending',
        }).toList();

        await _supabase.from('event_invitations').insert(invitations);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento creado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper date/time pickers
  Future<void> _pickDateTime(bool isStart) async {
    final DateTime initialDate = isStart ? _startDate : _endDate;
    final TimeOfDay initialTime = isStart ? _startTime : _endTime;

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date == null) return;

    if (!mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time == null) return;

    setState(() {
      if (isStart) {
        _startDate = date;
        _startTime = time;
        // Auto-adjust end time if it's earlier than new start time
        final newStart = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        final currentEnd = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);
        if (currentEnd.isBefore(newStart)) {
          _endDate = newStart.add(const Duration(hours: 1));
          _endTime = TimeOfDay.fromDateTime(_endDate);
        }
      } else {
        _endDate = date;
        _endTime = time;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy HH:mm');

    return AlertDialog(
      title: const Text('Nuevo Evento'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título del evento',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Fechas
              ListTile(
                title: const Text('Inicio'),
                subtitle: Text(format.format(DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute))),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateTime(true),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              ),
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Fin'),
                subtitle: Text(format.format(DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute))),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDateTime(false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              ),
              
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Evento Público'),
                subtitle: Text(_isPublic ? 'Visible en Calendario Grupal' : 'Visible solo en Mi Calendario y para invitados'),
                value: _isPublic,
                onChanged: (val) {
                  setState(() => _isPublic = val);
                },
              ),

              if (!_isPublic && _profiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Invitar a: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final p = _profiles[index];
                      final id = p['id'] as String;
                      return CheckboxListTile(
                        title: Text(p['full_name'] ?? p['email'] ?? 'Usuario'),
                        value: _selectedUserIds.contains(id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUserIds.add(id);
                            } else {
                              _selectedUserIds.remove(id);
                            }
                          });
                        },
                      );
                    },
                  ),
                )
              ]
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveEvent,
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar'),
        ),
      ],
    );
  }
}
