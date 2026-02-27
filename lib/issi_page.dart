import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'widgets/page_header.dart';

class IssiPage extends StatefulWidget {
  const IssiPage({super.key});

  @override
  State<IssiPage> createState() => _IssiPageState();
}

class _IssiPageState extends State<IssiPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterTipo;
  String? _filterCondicion;
  int _currentPage = 0;
  static const int _itemsPerPage = 20;
  bool _isAdmin = false;

  static const List<String> _tipos = [
    'LAPTOP',
    'PC',
    'IMPRESORA',
    'CELULAR',
    'TELEFONO',
    'DISCO DURO',
    'MONITOR',
    'MOUSE',
  ];

  static const List<String> _condiciones = [
    'NUEVO',
    'USADO',
    'DAÑADO',
    'SIN REPARACION',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _fetchItems();
    _fetchUsuarios();
  }

  Future<void> _checkAdminRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final role = user.userMetadata?['role'] ?? 'usuario';
        setState(() => _isAdmin = role == 'admin');
      }
    } catch (e) {
      debugPrint('Error checking admin role: $e');
    }
  }

  Future<void> _fetchUsuarios() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name')
          .order('full_name');
      if (mounted) {
        setState(() {
          _usuarios = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error fetching usuarios: $e');
    }
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('issi_inventory')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar inventario: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Eliminar Elemento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Estás seguro de que deseas eliminar este elemento? Esta acción no se puede deshacer.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ELIMINAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('issi_inventory').delete().eq('id', id);
        _fetchItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Elemento eliminado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showItemForm({Map<String, dynamic>? item}) {
    final isEditing = item != null;
    final ubicacionController = TextEditingController(text: item?['ubicacion']);
    final marcaController = TextEditingController(text: item?['marca']);
    final modeloController = TextEditingController(text: item?['modelo']);
    final nsController = TextEditingController(text: item?['n_s']);
    final imeiController = TextEditingController(text: item?['imei']);
    final cpuController = TextEditingController(text: item?['cpu']);
    final ssdController = TextEditingController(text: item?['ssd']);
    final ramController = TextEditingController(text: item?['ram']);
    final gpuController = TextEditingController(text: item?['gpu']);
    final fechaActController = TextEditingController(text: item?['fecha_actualizacion']);
    final valorController = TextEditingController(
      text: item?['valor']?.toString() ?? '',
    );
    final observacionesController = TextEditingController(text: item?['observaciones']);
    
    String tipo = item?['tipo']?.toString().toUpperCase() ?? _tipos.first;
    String condicion = item?['condicion']?.toString().toUpperCase() ?? _condiciones.first;
    
    String? selectedUsuarioId = item?['usuario_id'];
    String? selectedUsuarioNombre = item?['usuario_nombre'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: StatefulBuilder(
          builder: (context, setDialogState) => Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Editar Elemento' : 'Nuevo Elemento',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: selectedUsuarioId,
                      decoration: const InputDecoration(
                        labelText: 'Usuario *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      isExpanded: true,
                      items: _usuarios.map((u) => DropdownMenuItem(
                        value: u['id'] as String,
                        child: Text(u['full_name'] ?? 'Usuario'),
                      )).toList(),
                      onChanged: (val) {
                        final usuario = _usuarios.firstWhere((u) => u['id'] == val);
                        setDialogState(() {
                          selectedUsuarioId = val;
                          selectedUsuarioNombre = usuario['full_name'];
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ubicacionController,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación *',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo *',
                        prefixIcon: Icon(Icons.devices_outlined),
                      ),
                      isExpanded: true,
                      items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDialogState(() => tipo = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: marcaController,
                      decoration: const InputDecoration(
                        labelText: 'Marca *',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: modeloController,
                      decoration: const InputDecoration(
                        labelText: 'Modelo *',
                        prefixIcon: Icon(Icons.label_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nsController,
                      decoration: const InputDecoration(
                        labelText: 'N/S',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: imeiController,
                      decoration: const InputDecoration(
                        labelText: 'IMEI',
                        prefixIcon: Icon(Icons.sim_card_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cpuController,
                            decoration: const InputDecoration(
                              labelText: 'CPU',
                              prefixIcon: Icon(Icons.memory),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: ssdController,
                            decoration: const InputDecoration(
                              labelText: 'SSD',
                              prefixIcon: Icon(Icons.storage),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ramController,
                            decoration: const InputDecoration(
                              labelText: 'RAM',
                              prefixIcon: Icon(Icons.sd_card),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: valorController,
                            decoration: const InputDecoration(
                              labelText: 'Valor',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: gpuController,
                      decoration: const InputDecoration(
                        labelText: 'GPU',
                        prefixIcon: Icon(Icons.videogame_asset_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: fechaActController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Actualización',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      readOnly: true,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2101),
                        );
                        if (d != null) {
                          setDialogState(() => fechaActController.text = d.toString().split(' ').first);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: condicion,
                      decoration: const InputDecoration(
                        labelText: 'Condición *',
                        prefixIcon: Icon(Icons.health_and_safety_outlined),
                      ),
                      isExpanded: true,
                      items: _condiciones.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setDialogState(() => condicion = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: observacionesController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCELAR'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (ubicacionController.text.isEmpty || marcaController.text.isEmpty || 
                                  modeloController.text.isEmpty || selectedUsuarioId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Completa los campos obligatorios (*)')),
                                );
                                return;
                              }

                              try {
                                final data = {
                                  'ubicacion': ubicacionController.text.trim(),
                                  'tipo': tipo,
                                  'marca': marcaController.text.trim(),
                                  'modelo': modeloController.text.trim(),
                                  'n_s': nsController.text.trim().isEmpty ? null : nsController.text.trim(),
                                  'imei': imeiController.text.trim().isEmpty ? null : imeiController.text.trim(),
                                  'cpu': cpuController.text.trim().isEmpty ? null : cpuController.text.trim(),
                                  'ssd': ssdController.text.trim().isEmpty ? null : ssdController.text.trim(),
                                  'ram': ramController.text.trim().isEmpty ? null : ramController.text.trim().toUpperCase(),
                                  'gpu': gpuController.text.trim().isEmpty ? null : gpuController.text.trim().toUpperCase(),
                                  'fecha_actualizacion': fechaActController.text.isEmpty ? null : fechaActController.text,
                                  'valor': valorController.text.trim().isEmpty ? null : double.tryParse(valorController.text.trim()),
                                  'condicion': condicion,
                                  'observaciones': observacionesController.text.trim().isEmpty ? null : observacionesController.text.trim().toUpperCase(),
                                  'usuario_id': selectedUsuarioId,
                                  'usuario_nombre': selectedUsuarioNombre,
                                };

                                if (isEditing) {
                                  await Supabase.instance.client.from('issi_inventory').update(data).eq('id', item['id']);
                                } else {
                                  await Supabase.instance.client.from('issi_inventory').insert(data);
                                }

                                if (mounted) {
                                  Navigator.pop(context);
                                  _fetchItems();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isEditing ? 'Elemento actualizado' : 'Elemento creado con éxito'),
                                      backgroundColor: const Color(0xFFB1CB34),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            child: Text(isEditing ? 'GUARDAR' : 'CREAR'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredItems {
    var result = _items;
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((item) {
        final marca = (item['marca'] ?? '').toString().toLowerCase();
        final modelo = (item['modelo'] ?? '').toString().toLowerCase();
        final ubicacion = (item['ubicacion'] ?? '').toString().toLowerCase();
        final usuario = (item['usuario_nombre'] ?? '').toString().toLowerCase();
        final ns = (item['n_s'] ?? '').toString().toLowerCase();
        final imei = (item['imei'] ?? '').toString().toLowerCase();
        return marca.contains(query) || 
               modelo.contains(query) || 
               ubicacion.contains(query) || 
               usuario.contains(query) || 
               ns.contains(query) ||
               imei.contains(query);
      }).toList();
    }
    if (_filterTipo != null) {
      result = result.where((item) => item['tipo'] == _filterTipo).toList();
    }
    if (_filterCondicion != null) {
      result = result.where((item) => item['condicion'] == _filterCondicion).toList();
    }
    return result;
  }

  List<Map<String, dynamic>> get _paginatedItems {
    final filtered = _filteredItems;
    final start = _currentPage * _itemsPerPage;
    if (start >= filtered.length) return [];
    final end = (start + _itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  int get _totalPages => (_filteredItems.length / _itemsPerPage).ceil().clamp(1, 9999);

  void _exportCsv() {
    final filtered = _filteredItems;
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar')),
      );
      return;
    }

    final headers = ['Ubicación', 'Tipo', 'Marca', 'Modelo', 'N/S', 'IMEI', 'CPU', 'SSD', 'RAM', 'GPU', 'Fecha Actualización', 'Valor', 'Condición', 'Observaciones', 'Usuario'];
    final rows = filtered.map((item) => [
      item['ubicacion'] ?? '',
      item['tipo'] ?? '',
      item['marca'] ?? '',
      item['modelo'] ?? '',
      item['n_s'] ?? '',
      item['imei'] ?? '',
      item['cpu'] ?? '',
      item['ssd'] ?? '',
      item['ram'] ?? '',
      item['gpu'] ?? '',
      item['fecha_actualizacion'] ?? '',
      item['valor']?.toString() ?? '',
      item['condicion'] ?? '',
      item['observaciones'] ?? '',
      item['usuario_nombre'] ?? '',
    ].map((field) => '"${field.toString().replaceAll('"', '""')}"').join(',')).toList();

    final csvContent = [headers.join(','), ...rows].join('\n');
    debugPrint('CSV Export: ${rows.length} registros generados');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV generado: ${rows.length} registros exportados'),
        backgroundColor: const Color(0xFFB1CB34),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(backgroundColor: Colors.grey[200]),
        title: Container(height: 14, width: 150, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(height: 10, width: 50, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              Container(height: 10, width: 40, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _paginatedItems;
    final totalFiltered = _filteredItems.length;

    return Scaffold(
      floatingActionButton: _isAdmin 
        ? FloatingActionButton.extended(
            onPressed: () => _showItemForm(),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('NUEVO'),
          )
        : null,
      body: Column(
        children: [
          PageHeader(
            title: 'ISSI - Inventario',
            bottom: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por marca, modelo, N/S, ubicación...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() { _searchQuery = ''; _currentPage = 0; });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() { _searchQuery = value; _currentPage = 0; }),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text(_filterTipo ?? 'Tipo'),
                      selected: _filterTipo != null,
                      onSelected: (_) {
                        _showFilterDialog('Tipo', _tipos, _filterTipo, (val) {
                          setState(() { _filterTipo = val; _currentPage = 0; });
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text(_filterCondicion ?? 'Condición'),
                      selected: _filterCondicion != null,
                      onSelected: (_) {
                        _showFilterDialog('Condición', _condiciones, _filterCondicion, (val) {
                          setState(() { _filterCondicion = val; _currentPage = 0; });
                        });
                      },
                    ),
                    if (_filterTipo != null || _filterCondicion != null) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.clear, size: 16),
                        label: const Text('Limpiar'),
                        onPressed: () => setState(() { _filterTipo = null; _filterCondicion = null; _currentPage = 0; }),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => _buildShimmerItem(),
                  )
                : items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _filterTipo != null || _filterCondicion != null
                                  ? 'Sin resultados para los filtros aplicados'
                                  : 'No hay elementos en el inventario',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchItems,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length + (_totalPages > 1 ? 1 : 0),
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == items.length && _totalPages > 1) {
                              return _buildPaginationControls();
                            }
                            final item = items[index];
                            
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                  child: Icon(
                                    _getIconForType(item['tipo']),
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  '${item['marca']} ${item['modelo']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item['usuario_nombre']?.toString().toUpperCase() ?? 'SIN USUARIO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getColorForCondition(item['condicion']).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item['condicion'].toString().toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _getColorForCondition(item['condicion']),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: _isAdmin 
                                  ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showItemForm(item: item);
                                        } else if (value == 'delete') {
                                          _deleteItem(item['id']);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: ListTile(
                                            leading: Icon(Icons.edit),
                                            title: Text('Editar'),
                                            dense: true,
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: ListTile(
                                            leading: Icon(Icons.delete, color: Colors.red),
                                            title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                            dense: true,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                                children: [
                                  _buildDetailRow('Ubicación', item['ubicacion']),
                                  if (item['n_s'] != null) _buildDetailRow('N/S', item['n_s']),
                                  if (item['imei'] != null) _buildDetailRow('IMEI', item['imei']),
                                  if (item['cpu'] != null) _buildDetailRow('CPU', item['cpu']),
                                  if (item['ssd'] != null) _buildDetailRow('SSD', item['ssd']),
                                  if (item['ram'] != null) _buildDetailRow('RAM', item['ram']),
                                  if (item['gpu'] != null) _buildDetailRow('GPU', item['gpu']),
                                  if (item['fecha_actualizacion'] != null) _buildDetailRow('Fecha Actualización', item['fecha_actualizacion']),
                                  if (item['valor'] != null) _buildDetailRow('Valor', '\$${item['valor']}'),
                                  if (item['observaciones'] != null) _buildDetailRow('Observaciones', item['observaciones']),
                                  _buildDetailRow('Registrado por', item['usuario_nombre'] ?? 'Usuario'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(String title, List<String> options, String? currentValue, Function(String?) onSelected) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Filtrar por $title'),
        children: [
          if (currentValue != null)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                onSelected(null);
              },
              child: const Text('Todos', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ...options.map((option) => SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              onSelected(option);
            },
            child: Row(
              children: [
                if (option == currentValue) const Icon(Icons.check, size: 18, color: Colors.green),
                if (option == currentValue) const SizedBox(width: 8),
                Text(option),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Página ${_currentPage + 1} de $_totalPages',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages - 1 ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String tipo) {
    switch (tipo) {
      case 'Laptop':
        return Icons.laptop_mac;
      case 'PC':
        return Icons.desktop_mac;
      case 'Impresora':
        return Icons.print;
      case 'Celular':
        return Icons.smartphone;
      case 'Telefono':
        return Icons.phone;
      case 'Disco Duro':
        return Icons.storage;
      case 'Monitor':
        return Icons.monitor;
      case 'Mouse':
        return Icons.mouse;
      default:
        return Icons.devices_other;
    }
  }

  Color _getColorForCondition(String condicion) {
    switch (condicion) {
      case 'Nuevo':
        return Colors.green;
      case 'Usado':
        return Colors.orange;
      case 'Dañado':
        return Colors.red;
      case 'Sin Reparacion':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }
}
