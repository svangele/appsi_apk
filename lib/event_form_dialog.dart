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
  final _locationController = TextEditingController();
  final _supabase = Supabase.instance.client;

  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _endTime = TimeOfDay.now().replacing(
    hour: (TimeOfDay.now().hour + 1) % 24,
  );

  bool _isPublic = true; // Empieza con la opción público o personal
  String _recurrence = 'No repetir';
  final List<String> _recurrenceOptions = ['No repetir', 'Diariamente', 'Semanalmente', 'Mensualmente', 'Anualmente'];

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
      
      List<Map<String, dynamic>> allUsers = [];
      int offset = 0;
      const int limit = 1000;
      
      while (true) {
        final data = await _supabase
            .from('profiles')
            .select('id, full_name, email, permissions')
            .neq('id', currentUserId ?? '')
            .range(offset, offset + limit - 1);
            
        allUsers.addAll(List<Map<String, dynamic>>.from(data));
        if (data.length < limit) break;
        offset += limit;
      }
      
      if (mounted) {
        setState(() {
          _profiles = allUsers.where((user) {
             final perms = user['permissions'] as Map<String, dynamic>?;
             if (perms == null) return false;
             
             // Check robustly for true or "true"
             final hasPerm = perms['show_calendar'];
             return hasPerm == true || hasPerm == 'true';
          }).toList();
          
          // Sort alphabetically locally
          _profiles.sort((a, b) {
             final nameA = (a['full_name'] ?? a['email'] ?? '').toString().toLowerCase();
             final nameB = (b['full_name'] ?? b['email'] ?? '').toString().toLowerCase();
             return nameA.compareTo(nameB);
          });
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) return;

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
        'description': '', // Si quieres añadirlo después
        'location': _locationController.text.trim(),
        'recurrence': _recurrence,
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60.0), // Space for handle and header
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20, 
                right: 20, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 80 // Space for keyboard and safe area
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Tipo: Publico / Personal
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isPublic = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isPublic ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isPublic ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : null,
                                ),
                                child: const Center(
                                  child: Text('Público', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isPublic = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isPublic ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !_isPublic ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : null,
                                ),
                                child: const Center(
                                  child: Text('Personal', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. Título
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Título del evento',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                    Divider(color: Colors.grey.shade300),
                    
                    // 3. Ubicación o URL
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Añadir ubicación o URL',
                        icon: Icon(Icons.location_on_outlined, color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                    Divider(color: Colors.grey.shade300),
                    
                    // 4 & 5. Fechas (Inicio / Fin)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time, color: Colors.grey),
                      title: const Text('Comienza'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(format.format(DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute)), style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      onTap: () => _pickDateTime(true),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const SizedBox(width: 24), // Tabbing
                      title: const Text('Termina'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(format.format(DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute)), style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      onTap: () => _pickDateTime(false),
                    ),
                    Divider(color: Colors.grey.shade300),

                    // 6. Opción de repetir
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.repeat, color: Colors.grey),
                      title: const Text('Repetir'),
                      trailing: DropdownButton<String>(
                        value: _recurrence,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.chevron_right, color: Colors.grey),
                        items: _recurrenceOptions.map((e) {
                          return DropdownMenuItem(value: e, child: Text(e));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _recurrence = val);
                          }
                        },
                      ),
                    ),
                    Divider(color: Colors.grey.shade300),

                    // 7. Invitados (solo si es Personal)
                    if (!_isPublic) ...[
                      const SizedBox(height: 16),
                      const Text('Invitados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (_profiles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _profiles.length,
                          itemBuilder: (context, index) {
                            final p = _profiles[index];
                            final id = p['id'] as String;
                            final name = p['full_name'] ?? p['email'] ?? 'Usuario';
                            final isSelected = _selectedUserIds.contains(id);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
                                child: Text(name[0].toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : Colors.black54)),
                              ),
                              title: Text(name),
                              trailing: Switch(
                                value: isSelected,
                                activeColor: Colors.blue,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedUserIds.add(id);
                                    } else {
                                      _selectedUserIds.remove(id);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUserIds.remove(id);
                                  } else {
                                    _selectedUserIds.add(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Header / Drag handle
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                  const Text('Nuevo Evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _isLoading ? null : _saveEvent,
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Añadir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
