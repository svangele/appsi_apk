import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/page_header.dart';
import 'services/notification_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _collaborators = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _fetchUsers();
    _fetchCollaborators();
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

  Future<void> _fetchCollaborators() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, nombre, paterno, materno, numero_empleado, status_sys')
          .not('nombre', 'is', null)
          .order('nombre');
      setState(() => _collaborators = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error fetching collaborators: $e');
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);
      setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar usuarios: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String id) async {
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
                    'Eliminar Usuario',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '¿Estás seguro de que deseas eliminar este perfil? Esta acción no se puede deshacer.',
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
        await Supabase.instance.client.rpc('delete_user_admin', params: {'user_id': id});
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario y perfil eliminados correctamente')),
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

  void _showUserForm({Map<String, dynamic>? user}) {
    final isEditing = user != null;
    final isGrantingAccess = isEditing && (user['email'] == null || user['email'].toString().isEmpty);
    final theme = Theme.of(context);
    final nombreController = TextEditingController(text: user?['nombre']);
    final paternoController = TextEditingController(text: user?['paterno']);
    final maternoController = TextEditingController(text: user?['materno']);
    final employeeNumberController = TextEditingController(text: user?['numero_empleado']);
    final emailController = TextEditingController(text: user?['email']);
    final passwordController = TextEditingController();
    String role = user?['role'] ?? 'usuario';
    String? statusSys = user?['status_sys'] ?? 'ACTIVO';
    bool isBlocked = user?['is_blocked'] ?? false;
    final permissions = Map<String, bool>.from(user?['permissions'] ?? {
      'show_users': false,
      'show_issi': false,
      'show_cssi': false,
      'show_incidencias': false,
      'show_logs': false,
    });

    // Credential Controllers
    final drpUser = TextEditingController(text: user?['drp_user']);
    final drpPass = TextEditingController(text: user?['drp_pass']);
    final gpUser = TextEditingController(text: user?['gp_user']);
    final gpPass = TextEditingController(text: user?['gp_pass']);
    final bitrixUser = TextEditingController(text: user?['bitrix_user']);
    final bitrixPass = TextEditingController(text: user?['bitrix_pass']);
    final ekUser = TextEditingController(text: user?['ek_user']);
    final ekPass = TextEditingController(text: user?['ek_pass']);
    final otroUser = TextEditingController(text: user?['otro_user']);
    final otroPass = TextEditingController(text: user?['otro_pass']);

    final Map<String, bool> obscureStatus = {
      'drp': true, 'gp': true, 'bitrix': true, 'ek': true, 'otro': true,
    };

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
                          isGrantingAccess 
                            ? 'Conceder Acceso' 
                            : (isEditing 
                                ? 'Editar ${user['nombre'] ?? ''} ${user['paterno'] ?? ''}' 
                                : 'Crear Nuevo Usuario'),
                          style: theme.textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: statusSys,
                      decoration: const InputDecoration(
                        labelText: 'System Sys',
                        prefixIcon: Icon(Icons.settings_suggest_outlined),
                        filled: true,
                      ),
                      items: ['ACTIVO', 'BAJA', 'CAMBIO', 'ELIMINAR'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setDialogState(() => statusSys = val),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                        decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email)),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Contraseña (Dejar vacío para no cambiar)', prefixIcon: Icon(Icons.lock)),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      // Removed link logic as it is now one single table
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Rol del Sistema', prefixIcon: Icon(Icons.admin_panel_settings)),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'usuario', child: Text('Usuario')),
                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                      ],
                      onChanged: (val) => setDialogState(() => role = val!),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Estado de la Cuenta'),
                      subtitle: Text(isBlocked ? 'BLOQUEADA' : 'ACTIVA'),
                      secondary: Icon(isBlocked ? Icons.block : Icons.check_circle, color: isBlocked ? Colors.red : Colors.green),
                      value: !isBlocked,
                      onChanged: (val) => setDialogState(() => isBlocked = !val),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('ACCESOS (VISIBILIDAD)', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    const SizedBox(height: 16),
                    _buildPermissionSwitch('Gestión de Usuarios', 'show_users', Icons.group, permissions, setDialogState),
                    _buildPermissionSwitch('Inventario ISSI', 'show_issi', Icons.inventory_2, permissions, setDialogState),
                    _buildPermissionSwitch('Colaboradores CSSI', 'show_cssi', Icons.badge, permissions, setDialogState),
                    _buildPermissionSwitch('Peticiones de Incidencias', 'show_incidencias', Icons.description, permissions, setDialogState),
                    _buildPermissionSwitch('Logs del Sistema', 'show_logs', Icons.assignment, permissions, setDialogState),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('CREDENCIALES DE SISTEMAS', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    const SizedBox(height: 16),
                    _buildCredentialRow('DRP', drpUser, drpPass, 'drp', obscureStatus, setDialogState),
                    _buildCredentialRow('GP', gpUser, gpPass, 'gp', obscureStatus, setDialogState),
                    _buildCredentialRow('BITRIX', bitrixUser, bitrixPass, 'bitrix', obscureStatus, setDialogState),
                    _buildCredentialRow('ENKONTROL', ekUser, ekPass, 'ek', obscureStatus, setDialogState),
                    _buildCredentialRow('OTRO', otroUser, otroPass, 'otro', obscureStatus, setDialogState),
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
                              // Requisitos mínimos solo al CREAR o CONCEDER ACCESO inicial
                              if (!isEditing || isGrantingAccess) {
                                if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Correo y contraseña son obligatorios')),
                                  );
                                  return;
                                }
                              }
                              
                              // Si es EDICIÓN normal, correo es obligatorio pero password es opcional
                              if (isEditing && !isGrantingAccess) {
                                if (emailController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('El correo es obligatorio')),
                                  );
                                  return;
                                }
                              }

                              if (passwordController.text.trim().isNotEmpty && passwordController.text.trim().length < 8) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres')),
                                );
                                return;
                              }
                              try {
                                if (isEditing && !isGrantingAccess) {
                                  await Supabase.instance.client.rpc('update_user_admin', params: {
                                    'user_id_param': user['id'],
                                    'new_email': emailController.text.trim(),
                                    'new_full_name': '${nombreController.text} ${paternoController.text} ${maternoController.text}'.trim(),
                                    'new_role': role,
                                    'new_status_sys': statusSys,
                                    'is_blocked_param': isBlocked,
                                    'new_permissions': permissions,
                                    'new_password': passwordController.text.trim().isEmpty ? null : passwordController.text.trim(),
                                  });

                                  // Send notification if status is not ACTIVO
                                  if (statusSys != 'ACTIVO') {
                                    try {
                                      await NotificationService.send(
                                        title: 'Estatus Sys: ${nombreController.text} ${paternoController.text}',
                                        message: 'El colaborador ha sido marcado como $statusSys',
                                        type: 'collaborator_alert',
                                        metadata: {
                                          'profile_id': user['id'],
                                          'status': statusSys,
                                        },
                                      );
                                      debugPrint('[NOTIF] ✅ Enviada: $statusSys para ${nombreController.text}');
                                    } catch (notifErr) {
                                      debugPrint('[NOTIF] ❌ Error al enviar: $notifErr');
                                    }
                                  }
                                } else if (isGrantingAccess) {
                                  // Grant access to an existing profile
                                  await Supabase.instance.client.rpc('create_user_admin', params: {
                                    'email': emailController.text.trim(),
                                    'password': passwordController.text.trim(),
                                    'full_name': '${nombreController.text} ${paternoController.text} ${maternoController.text}'.trim(),
                                    'user_role': role,
                                    'user_id_param': user['id'], // Link to existing profile
                                  });
                                  // Update profile with credentials and set status to ACTIVO
                                  await Supabase.instance.client.from('profiles').update({
                                    'drp_user': drpUser.text.trim(),
                                    'drp_pass': drpPass.text.trim(),
                                    'gp_user': gpUser.text.trim(),
                                    'gp_pass': gpPass.text.trim(),
                                    'bitrix_user': bitrixUser.text.trim(),
                                    'bitrix_pass': bitrixPass.text.trim(),
                                    'ek_user': ekUser.text.trim(),
                                    'ek_pass': ekPass.text.trim(),
                                    'otro_user': otroUser.text.trim(),
                                    'otro_pass': otroPass.text.trim(),
                                    'status_sys': 'ACTIVO', // Set to ACTIVO when granting access
                                  }).eq('id', user['id']);
                                } else {
                                  // Creating new user
                                  final response = await Supabase.instance.client.rpc('create_user_admin', params: {
                                    'email': emailController.text.trim(),
                                    'password': passwordController.text.trim(),
                                    'full_name': '${nombreController.text} ${paternoController.text} ${maternoController.text}'.trim(),
                                    'user_role': role,
                                    'user_id_param': null, // No existing profile to link
                                  });

                                  final userId = response as String?;
                                  if (userId != null) {
                                    // Update profile with extra data (credentials)
                                    await Supabase.instance.client.from('profiles').update({
                                      'numero_empleado': employeeNumberController.text.trim(),
                                      'drp_user': drpUser.text.trim(),
                                      'drp_pass': drpPass.text.trim(),
                                      'gp_user': gpUser.text.trim(),
                                      'gp_pass': gpPass.text.trim(),
                                      'bitrix_user': bitrixUser.text.trim(),
                                      'bitrix_pass': bitrixPass.text.trim(),
                                      'ek_user': ekUser.text.trim(),
                                      'ek_pass': ekPass.text.trim(),
                                      'otro_user': otroUser.text.trim(),
                                      'otro_pass': otroPass.text.trim(),
                                      'status_sys': statusSys,
                                    }).eq('id', userId);

                                    // Send notification if status is not ACTIVO
                                    if (statusSys != 'ACTIVO') {
                                      try {
                                        await NotificationService.send(
                                          title: 'Estatus Sys: ${nombreController.text} ${paternoController.text}',
                                          message: 'Nuevo colaborador creado con estatus $statusSys',
                                          type: 'collaborator_alert',
                                          metadata: {
                                            'profile_id': userId,
                                            'status': statusSys,
                                          },
                                        );
                                        debugPrint('[NOTIF] ✅ Enviada (crear): $statusSys');
                                      } catch (notifErr) {
                                        debugPrint('[NOTIF] ❌ Error al enviar (crear): $notifErr');
                                      }
                                    }
                                  }
                                }
                                if (mounted) {
                                  Navigator.pop(context);
                                  _fetchUsers();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isGrantingAccess ? 'Acceso concedido exitosamente' : (isEditing ? 'Usuario actualizado' : 'Usuario creado')),
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
                            child: Text(isGrantingAccess ? 'CONCEDER ACCESO' : (isEditing ? 'GUARDAR' : 'CREAR')),
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

  Widget _buildPermissionSwitch(String title, String key, IconData icon, Map<String, bool> permissions, StateSetter setDialogState) {
    return CheckboxListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      secondary: Icon(icon, size: 20),
      value: permissions[key] ?? false,
      onChanged: (val) => setDialogState(() => permissions[key] = val ?? false),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCredentialRow(String label, TextEditingController uCtrl, TextEditingController pCtrl, String key, Map<String, bool> obscureMap, StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: uCtrl,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: pCtrl,
                obscureText: obscureMap[key] ?? true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  suffixIcon: IconButton(
                    icon: Icon(
                      (obscureMap[key] ?? true) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setDialogState(() => obscureMap[key] = !(obscureMap[key] ?? true)),
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final nombre = (user['nombre'] ?? '').toString().toLowerCase();
      final paterno = (user['paterno'] ?? '').toString().toLowerCase();
      final materno = (user['materno'] ?? '').toString().toLowerCase();
      final fullName = (user['full_name'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final numEmp = (user['numero_empleado'] ?? '').toString().toLowerCase();
      return nombre.contains(query) || paterno.contains(query) || materno.contains(query) || 
             fullName.contains(query) || role.contains(query) || numEmp.contains(query);
    }).toList();
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
        title: Container(height: 14, width: 120, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(height: 10, width: 60, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = _filteredUsers;

    return Scaffold(
      floatingActionButton: _isAdmin 
        ? FloatingActionButton.extended(
            onPressed: () => _showUserForm(),
            backgroundColor: theme.colorScheme.secondary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('NUEVO'),
          )
        : null,
      body: Column(
              children: [
                PageHeader(
                  title: 'Panel de Control',
                  subtitle: 'Total: ${_users.length} usuarios registrados',
                  bottom: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o rol...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
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
                      : RefreshIndicator(
                    onRefresh: _fetchUsers,
                    child: users.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.person_search, size: 64, color: Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty ? 'Sin resultados para "$_searchQuery"' : 'No hay usuarios registrados',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final String role = user['role'] ?? 'usuario';
                        
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: role == 'admin' 
                                  ? theme.colorScheme.tertiary.withOpacity(0.1)
                                  : theme.colorScheme.secondary.withOpacity(0.1),
                              child: Icon(
                                role == 'admin' ? Icons.admin_panel_settings : Icons.person_outline,
                                color: role == 'admin' 
                                    ? theme.colorScheme.tertiary 
                                    : theme.colorScheme.secondary,
                              ),
                            ),
                            title: Text(
                              '${user['numero_empleado'] ?? '----'} | ${user['nombre'] ?? ''} ${user['paterno'] ?? ''} ${user['materno'] ?? ''}'.trim(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: (user['is_blocked'] ?? false) ? TextDecoration.lineThrough : null,
                                color: (user['is_blocked'] ?? false) ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] ?? 'Sin correo', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: role == 'admin' 
                                              ? theme.colorScheme.tertiary.withOpacity(0.1)
                                              : theme.colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: role == 'admin' 
                                                ? theme.colorScheme.tertiary 
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                      if (user['is_blocked'] ?? false) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'BLOQUEADO',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 12),
                                      // Permission Indicators
                                      if (user['permissions'] != null) ...[
                                        _buildMiniIcon(Icons.group, user['permissions']['show_users'] == true),
                                        _buildMiniIcon(Icons.inventory_2, user['permissions']['show_issi'] == true),
                                        _buildMiniIcon(Icons.badge, user['permissions']['show_cssi'] == true),
                                        _buildMiniIcon(Icons.description, user['permissions']['show_incidencias'] == true),
                                        _buildMiniIcon(Icons.assignment, user['permissions']['show_logs'] == true),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            trailing: _isAdmin 
                              ? PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      _showUserForm(user: user);
                                    } else if (value == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Eliminar Usuario'),
                                          content: const Text('¿Estás seguro de que deseas eliminar este usuario? Esta acción no se puede deshacer.'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                              child: const Text('ELIMINAR'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        try {
                                          await Supabase.instance.client.rpc('delete_user_admin', params: {'user_id_param': user['id']});
                                          _fetchUsers();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'), dense: true)),
                                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Eliminar', style: TextStyle(color: Colors.red)), dense: true)),
                                  ],
                                )
                              : null,
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

  Widget _buildMiniIcon(IconData icon, bool active) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Icon(
        icon,
        size: 14,
        color: active ? const Color(0xFF344092) : Colors.grey.withOpacity(0.3),
      ),
    );
  }
}
