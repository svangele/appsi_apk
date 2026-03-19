import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'event_form_dialog.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final CalendarController _calendarController = CalendarController();
  
  int _calendarMode = 0; 
  List<Appointment> _events = [];
  bool _isLoading = true;
  CalendarView _currentView = CalendarView.month;
  DateTime _currentDisplayDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _onViewChanged(ViewChangedDetails details) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = _calendarController.view ?? CalendarView.month;
      final date = details.visibleDates[details.visibleDates.length ~/ 2];
      
      bool shouldUpdate = false;
      if (_currentView != view) {
        _currentView = view;
        shouldUpdate = true;
      }
      if (_currentDisplayDate.month != date.month || _currentDisplayDate.year != date.year) {
        _currentDisplayDate = date;
        shouldUpdate = true;
      }
      
      if (shouldUpdate) {
        setState(() {});
      }
    });
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      List<dynamic> response;
      if (_calendarMode == 1) { // Grupal
        response = await _supabase
            .from('events')
            .select('*, profiles(full_name)')
            .eq('is_public', true)
            .order('start_time');
      } else { // Personal e invitados
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
          color: _calendarMode == 1 ? Colors.blue.shade500 : Colors.redAccent.shade400,
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
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => const EventFormDialog(),
    ).then((_) => _fetchEvents());
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

  String get _bottomLeftButtonText {
    if (_currentView == CalendarView.month) return 'Hoy';
    if (_currentView == CalendarView.day) return 'Semana';
    if (_currentView == CalendarView.week) return 'Mes';
    return 'Hoy';
  }

  void _onBottomLeftButtonPressed() {
    setState(() {
      if (_currentView == CalendarView.month) {
        _calendarController.displayDate = DateTime.now();
        _calendarController.view = CalendarView.day;
      } else if (_currentView == CalendarView.day) {
        _calendarController.view = CalendarView.week;
      } else if (_currentView == CalendarView.week) {
        _calendarController.view = CalendarView.month;
      }
    });
  }

  void _showMonthsGrid() {
    final year = _currentDisplayDate.year;
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
     
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(year.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, 
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _currentView = CalendarView.month;
                          _calendarController.view = CalendarView.month;
                          _calendarController.displayDate = DateTime(year, index + 1, 1);
                        });
                      },
                      child: Center(
                        child: Text(
                          months[index], 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildGlassPill({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = _currentDisplayDate.year;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Calendar Body
            Positioned.fill(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SfCalendar(
                      controller: _calendarController,
                      view: CalendarView.month,
                      onViewChanged: _onViewChanged,
                      allowedViews: const [
                        CalendarView.day,
                        CalendarView.week,
                        CalendarView.month,
                      ],
                      dataSource: EventDataSource(_events),
                      onTap: _onAppointmentTap,
                      headerHeight: 0, // Ocultar el header por defecto para usar nuestro diseño
                      viewHeaderStyle: const ViewHeaderStyle(
                        dayTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      monthViewSettings: const MonthViewSettings(
                        showAgenda: true,
                        appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                      ),
                      timeSlotViewSettings: const TimeSlotViewSettings(
                        startHour: 7,
                        endHour: 22,
                      ),
                      selectionDecoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: Colors.redAccent, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
            ),

            // Top Left Pill: Year
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: _showMonthsGrid,
                child: _buildGlassPill(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black87),
                      const SizedBox(width: 4),
                      Text(
                        '$currentYear',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Right Pill: Controls
            Positioned(
              top: 16,
              right: 16,
              child: _buildGlassPill(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _onBottomLeftButtonPressed, // Mismo efecto que cambiar la vista
                      child: const Icon(Icons.view_agenda_outlined, color: Colors.black87),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscador no implementado aún')));
                      },
                      child: const Icon(Icons.search, color: Colors.black87),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _showAddEventDialog,
                      child: const Icon(Icons.add, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Left Pill: Hoy / Vista
            Positioned(
              bottom: 16,
              left: 16,
              child: GestureDetector(
                onTap: _onBottomLeftButtonPressed,
                child: _buildGlassPill(
                  child: Text(
                    _bottomLeftButtonText,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
              ),
            ),

            // Bottom Right Pill: Tabs (Personal / Grupal)
            Positioned(
              bottom: 16,
              right: 16,
              child: _buildGlassPill(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabIcon(Icons.person, 0),
                    const SizedBox(width: 8),
                    _buildTabIcon(Icons.groups, 1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabIcon(IconData icon, int mode) {
    final isSelected = _calendarMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _calendarMode = mode);
        _fetchEvents();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey.shade200 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: isSelected ? Colors.black : Colors.grey.shade600),
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<Appointment> source) {
    appointments = source;
  }
}
