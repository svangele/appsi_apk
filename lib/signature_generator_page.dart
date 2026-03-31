import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BrandConfig {
  final String name;
  final String background;
  final String facebook;
  final String instagram;
  final String web;

  BrandConfig({
    required this.name,
    required this.background,
    required this.facebook,
    required this.instagram,
    required this.web,
  });
}

class SignatureGeneratorPage extends StatefulWidget {
  const SignatureGeneratorPage({super.key});

  @override
  State<SignatureGeneratorPage> createState() => _SignatureGeneratorPageState();
}

class _SignatureGeneratorPageState extends State<SignatureGeneratorPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  
  final List<BrandConfig> _brands = [
    BrandConfig(name: 'Si Sol', background: 'assets/firmcred/sisol.png', facebook: 'sisolmx', instagram: 'sisolmx', web: 'sisol.com.mx'),
    BrandConfig(name: 'AG 117', background: 'assets/firmcred/ag117.png', facebook: 'ag117cdmx', instagram: 'AG117.cdmx', web: 'sisol.com.mx'),
    BrandConfig(name: 'Bonanza', background: 'assets/firmcred/bonanza.png', facebook: 'bonanzaprisma', instagram: 'bonanzaprisma', web: 'bonanzaprisma.com'),
    BrandConfig(name: 'Olympia', background: 'assets/firmcred/olympia.png', facebook: 'olympiaresidencial', instagram: 'olympiaresidencial', web: 'olympiaresidencial.com'),
    BrandConfig(name: 'Punta Pacífico', background: 'assets/firmcred/punta.png', facebook: 'puntapacifico.ensenada', instagram: 'puntapacifico.ensenada', web: 'puntapacifico.com.mx'),
    BrandConfig(name: 'Selva Norte', background: 'assets/firmcred/selva.png', facebook: 'selvanortetulum', instagram: 'selvanortetulum', web: 'selvanorte.com'),
    BrandConfig(name: 'VidaMar', background: 'assets/firmcred/vidamar.png', facebook: 'vidamarresidencial', instagram: 'vidamarresidencial', web: 'vidamarresidencial.com'),
  ];

  late BrandConfig _selectedBrand;
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedBrand = _brands[0];
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && data != null) {
          setState(() {
            _nameController.text = '${data['nombre'] ?? ''} ${data['paterno'] ?? ''} ${data['materno'] ?? ''}'.trim();
            _positionController.text = data['puesto'] ?? data['role'] ?? '';
            _phoneController.text = data['celular'] ?? data['telefono'] ?? '';
            _emailController.text = user.email ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSignature() async {
    final image = await _screenshotController.capture();
    if (image == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/firma_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(image);

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'Mi firma profesional');
      }
    } catch (e) {
      debugPrint('Error sharing signature: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 950;

          if (isDesktop) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Configuration
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: _buildConfigurationForm(theme),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right Column: Preview (Fixed width approx)
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildPreviewCard(theme),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: _buildDownloadButton(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile Layout (Current)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPreviewCard(theme),
                const SizedBox(height: 24),
                _buildConfigurationForm(theme),
                const SizedBox(height: 32),
                _buildDownloadButton(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.grey[200],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Screenshot(
                controller: _screenshotController,
                child: _buildSignaturePreview(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Vista Previa (787x200)', 
              style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand Selector
        Text('Selecciona la Marca', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final brand = _brands[index];
              final isSelected = _selectedBrand == brand;
              return InkWell(
                onTap: () => setState(() => _selectedBrand = brand),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!, width: 2),
                        image: DecorationImage(
                          image: AssetImage(brand.background),
                          fit: BoxFit.cover,
                          alignment: Alignment.centerRight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(brand.name, style: TextStyle(
                      fontSize: 10, 
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : Colors.black,
                    )),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // Form Fields
        Text('Información de Contacto', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Nombre Completo', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _positionController,
          decoration: const InputDecoration(labelText: 'Puesto / Cargo', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Correo', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    return ElevatedButton.icon(
      onPressed: _saveSignature,
      icon: const Icon(Icons.download),
      label: const Text('Descargar Firma (PNG)'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSignaturePreview() {
    // Layout mimicking the provided image
    return SizedBox(
      width: 787,
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_selectedBrand.background),
            fit: BoxFit.fill, // Use fill to ensure it matches the 787x200 exactly
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            Text(
              _nameController.text.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
            // Position
            Text(
              _positionController.text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
            
            const Spacer(),
            
            // Bottom Info Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Left Column: Phone & Email
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSignatureItem(Icons.phone_android_outlined, _phoneController.text),
                      const SizedBox(height: 4),
                      _buildSignatureItem(Icons.email_outlined, _emailController.text),
                    ],
                  ),
                ),
                
                // Right Column: Web & Social
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSignatureItem(Icons.public, _selectedBrand.web),
                      const SizedBox(height: 4),
                      _buildSocialItem(),
                    ],
                  ),
                ),
                
                // Logo area (right part of the background contains the logo usually)
                const Expanded(flex: 3, child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF00BFFF), size: 10),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 9),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialItem() {
    final bool sameHandle = _selectedBrand.facebook == _selectedBrand.instagram;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sameHandle) ...[
          const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF00BFFF), size: 10),
          const SizedBox(width: 4),
          const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFF00BFFF), size: 10),
          const SizedBox(width: 6),
          Text(_selectedBrand.facebook, style: const TextStyle(color: Colors.white, fontSize: 9)),
        ] else ...[
          const FaIcon(FontAwesomeIcons.facebook, color: Color(0xFF00BFFF), size: 10),
          const SizedBox(width: 4),
          Text(_selectedBrand.facebook, style: const TextStyle(color: Colors.white, fontSize: 9)),
          const SizedBox(width: 8),
          const FaIcon(FontAwesomeIcons.instagram, color: Color(0xFF00BFFF), size: 10),
          const SizedBox(width: 4),
          Text(_selectedBrand.instagram, style: const TextStyle(color: Colors.white, fontSize: 9)),
        ],
      ],
    );
  }
}
