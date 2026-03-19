import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _query = widget.initialValue;
    _controller.addListener(() {
      setState(() {
        _query = _controller.text;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            // Share logic would normally use share_plus, but we simulate it here or just copy for now
            _copyToClipboard(url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compartir no disponible, enlace copiado en su lugar')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMockMapSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_query.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Ubicaciones en mapa', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent.shade400,
              child: const Icon(Icons.location_on, color: Colors.white, size: 20),
            ),
            title: Text(_query, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Ubicación personalizada'),
            onTap: () => Navigator.pop(context, _query.trim()),
          ),
          const Divider(height: 1, indent: 64),
        ],
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Recientes', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue.shade100,
            child: const Icon(Icons.my_location, color: Colors.blue, size: 20),
          ),
          title: const Text('Ubicación actual'),
          onTap: () {
            Navigator.pop(context, 'Ubicación actual');
          },
        ),
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
                    _buildMockMapSuggestions()
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
