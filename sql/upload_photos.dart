import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final supabaseUrl = 'https://zkmbebybyyefmqcxjqrg.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InprbWJlYnlieXllZm1xY3hqcXJnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NzI4NDYsImV4cCI6MjA4ODE0ODg0Nn0.Imp2o34_Uvj_LvO-jdtGJTxeiJ3CmZFB4MUuWJxUpCs';
  
  final dir = Directory('../assets/fotos');
  
  if (!dir.existsSync()) {
    print('Directorio de fotos no encontrado en: ' + dir.path);
    return;
  }
  
  final files = dir.listSync().whereType<File>().toList();
  print('Total de archivos a procesar: ' + files.length.toString());
  
  int success = 0;
  int failed = 0;
  
  for (var file in files) {
    String filename = file.uri.pathSegments.last;
    String nameWithoutExt = filename.split('.').first;
    String ext = filename.split('.').last.toLowerCase();
    
    // Ignorar non-employee fotos temporalmente
    if (nameWithoutExt.toLowerCase() == 'avatar') continue;
    
    if (ext == 'jpeg') ext = 'jpeg';
    else if (ext == 'png') ext = 'png';
    else ext = 'jpeg'; // default para jpg
    
    String paddedName = nameWithoutExt.padLeft(4, '0');
    String newFilename = paddedName + '.jpg'; // Normalizar todos hacia .jpg para simplificar URLs  
    
    final bytes = await file.readAsBytes();
    
    final response = await http.post(
      Uri.parse(supabaseUrl + '/storage/v1/object/employee_photos/' + newFilename),
      headers: {
        'apikey': supabaseKey,
        'Authorization': 'Bearer ' + supabaseKey,
        'Content-Type': 'image/' + ext,
      },
      body: bytes,
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      success++;
      if (success % 50 == 0) {
        print('... Subidas ' + success.toString() + ' fotos.');
      }
    } else {
      // Ignorar errores de archivo existente "409" o "Duplicate" y solo notificar si son otros.
      if (response.statusCode != 400 && !response.body.contains("Duplicate")) {
         print('Falla con ' + filename + ': ' + response.statusCode.toString() + ' - ' + response.body);
      }
      failed++;
    }
  }
  
  print('Carga completada. Exitosas: ' + success.toString() + ', Fallidas o Duplicadas: ' + failed.toString());
}
