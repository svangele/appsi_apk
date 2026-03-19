import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_form_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isGroupCalendar = true; // true = Grupal, false = Personal
  List<Appointment> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      List<dynamic> response;
      if (_isGroupCalendar) {
        // Fetch public events
        response = await _supabase
            .from('events')
            .select('*, profiles(full_name)')
            .eq('is_public', true)
            .order('start_time');
      } else {
        // Fetch personal events (created by user OR user invited)
        // Since we have RLS, we can just fetch all events we have access to where is_public is false
        // RLS policy: "Private events viewable by creator" & "Invited users can view the event"
        response = await _supabase
            .from('events')
            .select('*, profiles(full_name)')
            .eq('is_public', false)
            .order('start_time');
      }

      final List<Appointment> loadedEvents = [];
      for (var ev in response) {
        final startTime = DateTime.parse(ev['start_time']).toLocal();
        final endTime = DateTime.parse(ev['end_time']).toLocal();
        final isAllDay = (endTime.difference(startTime).inHours >= 24);
        final creatorName = ev['profiles']?['full_name'] ?? 'Usuario';

        loadedEvents.add(Appointment(
          id: ev['id'],
          startTime: startTime,
          endTime: endTime,
          subject: ev['title'],
          notes: '${ev['description'] ?? ''}\nCreado por: $creatorName',
          color: _isGroupCalendar ? Colors.blue.shade600 : Colors.teal.shade500,
          isAllDay: isAllDay,
        ));
      }

      if (mounted) {
        setState(() {
          _events = loadedEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar eventos: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => const EventFormDialog(),
    ).then((_) {
      // Refresh events when dialog closes
      _fetchEvents();
    });
  }

  void _onAppointmentTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final Appointment appointment = details.appointments!.first;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(appointment.subject),
          content: Text(
            'Inicio: ${appointment.startTime.toString().substring(0, 16)}\n'
            'Fin: ${appointment.endTime.toString().substring(0, 16)}\n\n'
            '${appointment.notes}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Grupal'),
                        icon: Icon(Icons.groups),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Personal'),
                        icon: Icon(Icons.person),
                      ),
                    ],
                    selected: {_isGroupCalendar},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isGroupCalendar = newSelection.first;
                      });
                      _fetchEvents();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SfCalendar(
              view: CalendarView.month,
              allowedViews: const [
                CalendarView.day,
                CalendarView.week,
                CalendarView.workWeek,
                CalendarView.month,
                CalendarView.schedule
              ],
              dataSource: EventDataSource(_events),
              onTap: _onAppointmentTap,
              monthViewSettings: const MonthViewSettings(
                showAgenda: true,
                appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
              ),
              timeSlotViewSettings: const TimeSlotViewSettings(
                startHour: 7,
                endHour: 22,
              ),
              selectionDecoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                shape: BoxShape.rectangle,
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Evento'),
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<Appointment> source) {
    appointments = source;
  }
}
