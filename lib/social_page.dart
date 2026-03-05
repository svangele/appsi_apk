import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'widgets/page_header.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  List<Map<String, dynamic>> _allBirthdays = [];
  bool _isLoading = true;
  int _selectedMonth = DateTime.now().month;

  final List<String> _months = [
    'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
    'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'
  ];

  @override
  void initState() {
    super.initState();
    _fetchBirthdays();
  }

  Future<void> _fetchBirthdays() async {
    setState(() => _isLoading = true);
    try {
      // Obtenemos todos los colaboradores que tengan fecha de nacimiento
      final data = await Supabase.instance.client
          .from('profiles')
          .select('nombre, paterno, materno, fecha_nacimiento, foto_url, ubicacion')
          .not('fecha_nacimiento', 'is', null)
          .neq('status_rh', 'BAJA')
          .eq('status_sys', 'ACTIVO')
          .order('nombre');

      if (mounted) {
        setState(() {
          _allBirthdays = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching birthdays: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cumpleaños: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBirthdays {
    return _allBirthdays.where((item) {
      final fechaStr = item['fecha_nacimiento'] as String?;
      if (fechaStr == null || fechaStr.isEmpty) return false;
      try {
        final date = DateTime.parse(fechaStr);
        return date.month == _selectedMonth;
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) {
        final dateA = DateTime.parse(a['fecha_nacimiento']);
        final dateB = DateTime.parse(b['fecha_nacimiento']);
        return dateA.day.compareTo(dateB.day);
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = _filteredBirthdays;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? Center(
              child: Image.asset(
                'assets/sisol_loader.gif',
                width: 150,
                errorBuilder: (context, error, stackTrace) => const CircularProgressIndicator(),
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                    frame == null ? const CircularProgressIndicator() : child,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: isDesktop 
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Birthdays
                          Expanded(
                            flex: 1,
                            child: _buildBirthdaySection(upcoming, theme),
                          ),
                          const SizedBox(width: 24),
                          // Middle Column (Future Section)
                          Expanded(
                            flex: 1,
                            child: _buildPlaceholderSection('Próximamente', Icons.auto_awesome_outlined),
                          ),
                          const SizedBox(width: 24),
                          // Right Column (Future Section)
                          Expanded(
                            flex: 1,
                            child: _buildPlaceholderSection('Próximamente', Icons.upcoming_outlined),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildBirthdaySection(upcoming, theme),
                          const SizedBox(height: 24),
                          _buildPlaceholderSection('Próximamente', Icons.auto_awesome_outlined),
                        ],
                      ),
                ),
              ),
            ),
    );
  }

  Widget _buildBirthdaySection(List<Map<String, dynamic>> upcoming, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Birthday Section Header with Gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF344092), Color(0xFF515DBB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF344092).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Cumpleaños 🎂',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    dropdownColor: const Color(0xFF344092),
                    icon: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                    items: List.generate(12, (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(
                        _months[index],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    )),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Content Area
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: upcoming.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _buildEmptyState(),
                )
              : _buildBirthdayList(upcoming, theme),
        ),
      ],
    );
  }

  Widget _buildBirthdayList(List<Map<String, dynamic>> items, ThemeData theme) {
    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final date = DateTime.parse(item['fecha_nacimiento']);
        final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month;

        return Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: item['foto_url'] != null ? NetworkImage(item['foto_url']) : null,
                    child: item['foto_url'] == null 
                      ? Icon(Icons.person, color: theme.colorScheme.primary, size: 20)
                      : null,
                  ),
                  if (isToday)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Text('👑', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                ],
              ),
              title: Text(
                '${item['nombre']} ${item['paterno']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                item['ubicacion'] ?? 'SIN UBICACIÓN',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: isToday ? Colors.orange : theme.colorScheme.primary
                    ),
                  ),
                  if (isToday)
                    const Text(
                      'HOY',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                ],
              ),
              onTap: () {},
            ),
            if (index < items.length - 1)
              Divider(height: 1, indent: 64, endIndent: 12, color: Colors.grey[100]),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cake_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No hay cumpleaños en ${_months[_selectedMonth - 1]}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderSection(String title, IconData icon) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.grey[200]),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
