import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class LocationSearchDialog extends StatefulWidget {
  final String initialValue;
  final bool isReadOnly;

  const LocationSearchDialog({
    super.key, 
    this.initialValue = '',
    this.isReadOnly = false,
  });

  @override
  State<LocationSearchDialog> createState() => _LocationSearchDialogState();
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  late TextEditingController _controller;
  String _query = '';
  List<String> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _query = widget.initialValue;
    _controller.addListener(() {
      setState(() {
        _query = _controller.text;
      });
      _onSearchChanged();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged() async {
    if (_query.trim().isEmpty || _isUrl(_query)) {
      setState(() => _suggestions = []);
      return;
    }
    
    // De-bounce using a simple delay could be added here, but for simplicity:
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(_query)}&format=json&addressdetails=1&limit=5');
      final response = await http.get(url, headers: {'User-Agent': 'appsi_apk/1.0'});
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<String> results = data.map((e) => e['display_name'] as String).toList();
        if (mounted) {
          setState(() {
            _suggestions = results;
          });
        }
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  bool _isUrl(String text) {
    final t = text.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://') || t.startsWith('www.');
  }

  Future<void> _launchUrl(String urlText) async {
    var u = urlText.trim();
    if (u.startsWith('www.')) {
      u = 'https://$u';
    }
    final uri = Uri.tryParse(u);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles')),
    );
  }

  Widget _buildUrlActions(String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Opciones de Enlace', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.open_in_browser, color: Colors.white, size: 20),
          ),
          title: const Text('Abrir URL'),
          onTap: () => _launchUrl(url),
        ),
        const Divider(height: 1, indent: 64),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.copy, color: Colors.black54, size: 20),
          ),
          title: const Text('Copiar URL'),
          onTap: () => _copyToClipboard(url),
        ),
        const Divider(height: 1, indent: 64),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.share, color: Colors.black54, size: 20),
          ),
          title: const Text('Compartir URL'),
          onTap: () {
            _copyToClipboard(url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compartir no disponible, enlace copiado en su lugar')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_query.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Escriba para buscar o seleccione una opción', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          if (_isSearching && _suggestions.isEmpty)
             const Padding(
               padding: EdgeInsets.all(16.0),
               child: Center(child: CircularProgressIndicator()),
             ),
          for (var suggestion in _suggestions) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.redAccent.shade400,
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              title: Text(suggestion, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, suggestion),
            ),
            const Divider(height: 1, indent: 64),
          ],
          
          if (_suggestions.isEmpty && !_isSearching) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: const Icon(Icons.location_on, color: Colors.white, size: 20),
              ),
              title: Text(_query, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Usar texto tal y como está...'),
              onTap: () => Navigator.pop(context, _query.trim()),
            ),
            const Divider(height: 1, indent: 64),
          ]
        ],
        
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUrl = _isUrl(_query);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Spacer to center title
                const Text(
                  'Ubicación o enlace', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _controller,
                autofocus: !widget.isReadOnly,
                readOnly: widget.isReadOnly,
                decoration: InputDecoration(
                  hintText: 'Buscar o ingresar enlace...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _query.isNotEmpty && !widget.isReadOnly
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                          onPressed: () => _controller.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    Navigator.pop(context, val.trim());
                  }
                },
              ),
            ),
          ),
          const Divider(height: 1),
          
          // Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_query.isNotEmpty && !isUrl && !widget.isReadOnly)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('"${_query}"', style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                    ),
                    
                  if (isUrl) 
                    _buildUrlActions(_query)
                  else if (!widget.isReadOnly) 
                    _buildMapSuggestions()
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
