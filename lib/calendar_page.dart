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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EventFormDialog(),
    ).then((_) => _fetchEvents());
  }

  void _onAppointmentTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment) {
      final Appointment appointment = details.appointments!.first;
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => EventFormDialog(eventId: appointment.id.toString()),
      ).then((_) => _fetchEvents());
    }
  }

  String get _bottomLeftButtonText {
    if (_currentView == CalendarView.month) return 'DIA';
    if (_currentView == CalendarView.day) return 'Semana';
    if (_currentView == CalendarView.week) return 'Mes';
    return 'DIA';
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
    int selectedYear = _currentDisplayDate.year;
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
     
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setModalState(() {
                            selectedYear--;
                          });
                        },
                      ),
                      Text(selectedYear.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setModalState(() {
                            selectedYear++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                              _calendarController.displayDate = DateTime(selectedYear, index + 1, 1);
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
    final monthsNames = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final currentMonthName = monthsNames[_currentDisplayDate.month - 1];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Controls (Not overlapping)
                Padding(
                  padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Left Pill: Year
                      GestureDetector(
                        onTap: _showMonthsGrid,
                        child: _buildGlassPill(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            '$currentYear',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ),
                      ),

                      // Top Right Pill: Search & Plus
                      _buildGlassPill(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                    ],
                  ),
                ),

                // Month Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Text(
                    currentMonthName,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),

                        // Calendar Body
                Expanded(
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
                          headerHeight: 0, 
                          cellBorderColor: Colors.transparent, // Remove all default borders
                          viewHeaderStyle: const ViewHeaderStyle(
                            dayTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                          ),
                          monthViewSettings: const MonthViewSettings(
                            dayFormat: 'EEEEE', // Single letter format
                            showAgenda: true, // Show events list below calendar when a day is tapped
                            showTrailingAndLeadingDates: false,
                            appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
                          ),
                          monthCellBuilder: (BuildContext context, MonthCellDetails details) {
                            final isToday = details.date.year == DateTime.now().year && 
                                            details.date.month == DateTime.now().month && 
                                            details.date.day == DateTime.now().day;
                            
                            // Only show cells for the current month
                            if (details.date.month != _currentDisplayDate.month) {
                              return const SizedBox.shrink();
                            }

                            return Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 2),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isToday ? Colors.redAccent.shade400 : Colors.transparent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        details.date.day.toString(),
                                        style: TextStyle(
                                          color: isToday ? Colors.white : Colors.black87,
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (details.appointments.isNotEmpty)
                                    ...details.appointments.take(3).map((app) {
                                      final appointment = app as Appointment;
                                      return Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: appointment.color,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          appointment.subject,
                                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          },
                          timeSlotViewSettings: const TimeSlotViewSettings(
                            startHour: 7,
                            endHour: 22,
                          ),
                          selectionDecoration: BoxDecoration(
                            color: Colors.transparent,
                          ),
                        ),
                ),
              ],
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
