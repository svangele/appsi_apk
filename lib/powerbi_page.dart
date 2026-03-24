import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PowerBiPage extends StatefulWidget {
  final String role;
  final Map<String, dynamic> permissions;

  const PowerBiPage({super.key, required this.role, required this.permissions});

  @override
  State<PowerBiPage> createState() => _PowerBiPageState();
}

class _PowerBiPageState extends State<PowerBiPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _userLinks = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = true;
  bool get _isAdmin => widget.role == 'admin' || widget.role == 'superadmin';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;

      if (_isAdmin) {
        final linksData = await _supabase
            .from('powerbi_links')
            .select('*')
            .order('created_at', ascending: false);
        _links = List<Map<String, dynamic>>.from(linksData);
      }

      // Obtener perfil del usuario actual para verificar permisos
      Map<String, dynamic>? currentUserProfile;
      try {
        final profileData = await _supabase
            .from('profiles')
            .select('permissions')
            .eq('id', userId ?? '')
            .single();
        currentUserProfile = Map<String, dynamic>.from(profileData);
      } catch (e) {
        debugPrint('Error fetching current user profile: $e');
      }

      final hasPowerBiPermission = currentUserProfile?['permissions'] is Map &&
          currentUserProfile?['permissions']['show_powerbi'] == true;

      // Si tiene permiso show_powerbi, puede ver los enlaces asignados o creados
      if (hasPowerBiPermission) {
        // Enlaces donde el usuario está asignado
        final userLinksData = await _supabase
            .from('powerbi_link_users')
            .select(
                'link_id, powerbi_links(id, title, url, html_code, is_active, created_by)')
            .eq('user_id', userId ?? '');

        final assignedLinks = (userLinksData as List)
            .where((item) {
              final link = item['powerbi_links'];
              return link != null && link['is_active'] == true;
            })
            .map((item) =>
                Map<String, dynamic>.from(item['powerbi_links'] as Map))
            .toList();

        // Enlaces donde el usuario es el creador
        final createdLinksData = await _supabase
            .from('powerbi_links')
            .select('id, title, url, html_code, is_active, created_by')
            .eq('created_by', userId ?? '')
            .eq('is_active', true);

        final createdLinks = (createdLinksData as List)
            .map((link) => Map<String, dynamic>.from(link))
            .toList();

        // Combinar y eliminar duplicados
        final allLinks = [...assignedLinks, ...createdLinks];
        final uniqueLinks = <String, Map<String, dynamic>>{};
        for (final link in allLinks) {
          uniqueLinks[link['id'].toString()] = link;
        }
        _userLinks = uniqueLinks.values.toList();
      } else {
        _userLinks = [];
      }

      if (_isAdmin) {
        final usersData = await _supabase
            .from('profiles')
            .select('id, nombre, paterno, materno, status_sys, permissions')
            .eq('status_sys', 'ACTIVO')
            .order('nombre');

        _availableUsers = (usersData as List)
            .where((user) {
              final perms = user['permissions'];
              return perms is Map && perms['show_powerbi'] == true;
            })
            .map((user) => Map<String, dynamic>.from(user))
            .toList();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching Power BI data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openLink(Map<String, dynamic> link) async {
    final url = link['url'] as String?;
    final htmlCode = link['html_code'] as String?;

    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el enlace')),
          );
        }
      }
    } else if (htmlCode != null && htmlCode.isNotEmpty) {
      if (mounted) {
        _showHtmlViewer(htmlCode, link['title'] ?? 'Reporte');
      }
    }
  }

  void _showHtmlViewer(String htmlCode, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 60),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  htmlCode,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinkForm({Map<String, dynamic>? link}) {
    final isEditing = link != null;
    final titleCtrl = TextEditingController(text: link?['title']);
    final urlCtrl = TextEditingController(text: link?['url']);
    final htmlCtrl = TextEditingController(text: link?['html_code']);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDesktop = MediaQuery.of(context).size.width > 800;
          return Container(
            height: isDesktop
                ? MediaQuery.of(context).size.height * 0.9
                : MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ),
                      Text(
                        isEditing ? 'Editar Enlace' : 'Nuevo Enlace',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (titleCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('El título es obligatorio')),
                                  );
                                  return;
                                }
                                setModalState(() => saving = true);
                                try {
                                  final data = {
                                    'title':
                                        titleCtrl.text.trim().toUpperCase(),
                                    'url': urlCtrl.text.trim().isEmpty
                                        ? null
                                        : urlCtrl.text.trim(),
                                    'html_code': htmlCtrl.text.trim().isEmpty
                                        ? null
                                        : htmlCtrl.text.trim(),
                                    'is_active': true,
                                    'created_by':
                                        _supabase.auth.currentUser?.id,
                                  };

                                  if (isEditing) {
                                    await _supabase
                                        .from('powerbi_links')
                                        .update(data)
                                        .eq('id', link['id']);
                                  } else {
                                    await _supabase
                                        .from('powerbi_links')
                                        .insert(data);
                                  }

                                  if (mounted) {
                                    Navigator.pop(context);
                                    _fetchData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Enlace actualizado'
                                            : 'Enlace creado'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => saving = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Guardar',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Título *',
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'URL',
                            prefixIcon: Icon(Icons.link),
                            hintText: 'https://...',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: htmlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Código HTML',
                            prefixIcon: Icon(Icons.code),
                            hintText: '<html>...</html>',
                          ),
                          maxLines: 5,
                        ),
                        if (isEditing) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Usuarios con acceso',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          _buildUserAccessList(link['id']),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserAccessList(String linkId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getLinkUsers(linkId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final assignedIds =
            snapshot.data?.map((u) => u['user_id'].toString()).toSet() ?? {};

        if (_availableUsers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No hay usuarios disponibles'),
          );
        }

        return Column(
          children: _availableUsers.map((user) {
            final userId = user['id'].toString();
            final isAssigned = assignedIds.contains(userId);
            final fullName =
                '${user['nombre'] ?? ''} ${user['paterno'] ?? ''} ${user['materno'] ?? ''}'
                    .trim();

            return _UserSwitchCard(
              user: user,
              fullName: fullName,
              linkId: linkId,
              initialValue: isAssigned,
              onChanged: () {
                setState(() {});
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getLinkUsers(String linkId) async {
    final data = await _supabase
        .from('powerbi_link_users')
        .select('user_id')
        .eq('link_id', linkId);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _deleteLink(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Enlace'),
        content: const Text('¿Estás seguro de eliminar este enlace?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('powerbi_links').delete().eq('id', id);
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enlace eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: Image.asset(
          'assets/sisol_loader.gif',
          width: 150,
          errorBuilder: (context, error, stackTrace) =>
              const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  _isAdmin ? _buildAdminHeader(theme) : _buildUserHeader(theme),
            ),
          ),
          _isAdmin ? _buildAdminContent(theme) : _buildUserContent(theme),
        ],
      ),
    );
  }

  Widget _buildUserHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Mis Reportes',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildAdminHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildGlassPill(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    isDense: true,
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const VerticalDivider(
                  width: 1, thickness: 1, indent: 8, endIndent: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 22),
                onPressed: () => _showLinkForm(),
                tooltip: 'Nuevo Enlace',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassPill({required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildUserContent(ThemeData theme) {
    if (_userLinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No tienes acceso a ningún reporte',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final link = _userLinks[index];
            return _buildLinkCard(link, theme, isAdmin: false);
          },
          childCount: _userLinks.length,
        ),
      ),
    );
  }

  Widget _buildAdminContent(ThemeData theme) {
    final filteredLinks = _searchQuery.isEmpty
        ? _links
        : _links.where((link) {
            final title = (link['title'] ?? '').toString().toLowerCase();
            return title.contains(_searchQuery.toLowerCase());
          }).toList();

    if (filteredLinks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isEmpty ? Icons.link_off : Icons.search_off,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? 'No hay enlaces creados'
                    : 'No se encontraron resultados',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final link = filteredLinks[index];
            return _buildLinkCard(link, theme, isAdmin: true);
          },
          childCount: filteredLinks.length,
        ),
      ),
    );
  }

  Widget _buildLinkCard(Map<String, dynamic> link, ThemeData theme,
      {required bool isAdmin}) {
    final hasUrl = link['url'] != null && link['url'].toString().isNotEmpty;
    final hasHtml =
        link['html_code'] != null && link['html_code'].toString().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openLink(link),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      hasHtml ? Icons.code : Icons.bar_chart,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          link['title'] ?? 'Sin título',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasUrl ? 'URL' : (hasHtml ? 'HTML' : 'Sin contenido'),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isAdmin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showLinkForm(link: link),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteLink(link['id']),
                      tooltip: 'Eliminar',
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Ver reporte',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserSwitchCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final String fullName;
  final String linkId;
  final bool initialValue;
  final VoidCallback onChanged;

  const _UserSwitchCard({
    required this.user,
    required this.fullName,
    required this.linkId,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_UserSwitchCard> createState() => _UserSwitchCardState();
}

class _UserSwitchCardState extends State<_UserSwitchCard> {
  late bool isAssigned;

  @override
  void initState() {
    super.initState();
    isAssigned = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _UserSwitchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      isAssigned = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          widget.fullName,
          style: const TextStyle(fontSize: 13),
        ),
        value: isAssigned,
        onChanged: (value) async {
          setState(() => isAssigned = value);
          try {
            final supabase = Supabase.instance.client;
            if (value) {
              await supabase.from('powerbi_link_users').insert({
                'link_id': widget.linkId,
                'user_id': widget.user['id'],
              });
            } else {
              await supabase
                  .from('powerbi_link_users')
                  .delete()
                  .eq('link_id', widget.linkId)
                  .eq('user_id', widget.user['id']);
            }
            widget.onChanged();
          } catch (e) {
            setState(() => isAssigned = !value);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }
}
