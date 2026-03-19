import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'calendar_event_form_dialog.dart';

class EventSearchDialog extends StatefulWidget {
  final int calendarMode; // 0 = Personal, 1 = Grupal

  const EventSearchDialog({super.key, required this.calendarMode});

  @override
  State<EventSearchDialog> createState() => _EventSearchDialogState();
}

class _EventSearchDialogState extends State<EventSearchDialog> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      final isPublic = widget.calendarMode == 1;
      
      final response = await _supabase
          .from('events')
          .select('id, title, start_time, end_time, location')
          .ilike('title', '%${query.trim()}%')
          .eq('is_public', isPublic)
          .order('start_time', ascending: true)
          .limit(20);

      if (mounted) {
        setState(() {
          _searchResults = response;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching events: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Buscar Eventos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF344092),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (val) => _performSearch(val),
            decoration: InputDecoration(
              hintText: 'Buscar por título...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF344092)),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? Center(
                    child: Image.asset(
                      'assets/sisol_loader.gif',
                      width: 100,
                    ),
                  )
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Escribe para buscar eventos'
                              : 'No se encontraron eventos',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final ev = _searchResults[index];
                          final startTime = DateTime.parse(ev['start_time']).toLocal();
                          final String formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'es_MX').format(startTime);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                ev['title'] ?? 'Sin título',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                  if (ev['location'] != null && ev['location'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              ev['location'],
                                              style: const TextStyle(color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pop(context); // Close search dialog
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => EventFormDialog(eventId: ev['id'].toString()),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
