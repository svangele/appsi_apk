import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class IncidenciasPdfService {
  static Future<void> generateVacationRequest(
    Map<String, dynamic> profile,
    Map<String, dynamic> incidencia,
  ) async {
    final pdf = pw.Document();

    final logoImage = pw.MemoryImage(
      (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
    );

    // Get profile image if available
    pw.ImageProvider? profileImage;
    if (profile['foto_url'] != null && profile['foto_url'].toString().isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(profile['foto_url']));
        if (response.statusCode == 200) {
          profileImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        print('Error fetching profile image: $e');
      }
    }

    final now = DateTime.now();
    final df = DateFormat('dd/MM/yyyy');
    final dfFull = DateFormat('EEEE, d \'de\' MMMM \'del\' yyyy', 'es_MX');

    final elaborationDate = incidencia['created_at'] != null 
        ? DateTime.parse(incidencia['created_at']) 
        : now;
    final startDate = DateTime.parse(incidencia['fecha_inicio']);
    final endDate = DateTime.parse(incidencia['fecha_fin']);
    final returnDate = DateTime.parse(incidencia['fecha_regreso']);

    final fullName = '${profile['nombre'] ?? ''} ${profile['paterno'] ?? ''} ${profile['materno'] ?? ''}'.trim();
    final area = profile['area'] ?? '---';
    final puesto = profile['puesto'] ?? profile['role'] ?? '---';
    final email = profile['email'] ?? '---'; // Supabase email usually comes from auth, but we might have it in profile
    final ubicacion = profile['ubicacion'] ?? '---';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Watermark
              pw.Opacity(
                opacity: 0.05,
                child: pw.Center(
                  child: pw.Container(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: List.generate(8, (i) => pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: List.generate(5, (j) => pw.Padding(
                          padding: const pw.EdgeInsets.all(30),
                          child: pw.Image(logoImage, width: 80),
                        )),
                      )),
                    ),
                  ),
                ),
              ),
              // Main Content
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Top Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(logoImage, width: 180),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('SI SOL INMOBILIARIAS, SAPI DE CV', 
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          pw.Text('SOLICITUD DE VACACIONES', 
                            style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('CDMX a ${df.format(now)}', 
                            style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  // User Info
                  pw.Row(
                    children: [
                      if (profileImage != null)
                        pw.ClipOval(
                          child: pw.Image(profileImage, width: 80, height: 80, fit: pw.BoxFit.cover),
                        )
                      else
                        pw.Container(
                          width: 80,
                          height: 80,
                          decoration: const pw.BoxDecoration(color: PdfColors.grey300, shape: pw.BoxShape.circle),
                        ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(fullName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                            pw.SizedBox(height: 5),
                            pw.Text(ubicacion, style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(area, style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(puesto, style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(email, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      // SI VACACIONES STAMP (Simulated)
                      pw.Container(
                        width: 100,
                        height: 100,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: PdfColors.blue900, width: 3),
                        ),
                        child: pw.Center(
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('SI', style: pw.TextStyle(color: PdfColors.blue900, fontWeight: pw.FontWeight.bold, fontSize: 30)),
                              pw.Text('VACACIONES', style: pw.TextStyle(color: PdfColors.red600, fontWeight: pw.FontWeight.bold, fontSize: 8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  // Dates Grid
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _dateColumn('FECHA DE ELABORACIÓN', df.format(elaborationDate)),
                      _dateColumn('FECHA DE INICIO', df.format(startDate)),
                      _dateColumn('FECHA DE FIN', df.format(endDate)),
                      _dateColumn('FECHA DE REGRESO', df.format(returnDate)),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  // Request Text
                  pw.Text(
                    'Por medio del presente solicito ${incidencia['dias']} dias(s) de vacaciones, las cuales serán disfrutadas del día ${df.format(startDate)} al ${df.format(endDate)}, sin contar domingos o días festivos, que estén dentro de este período.',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'La fecha en que debo incorporarme a trabajar, es a partir del día: ${dfFull.format(returnDate)}.',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Spacer(),
                  // Signatures
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _signatureBox('Solicitante', fullName, puesto),
                      _signatureBox('Vo. Bo. Jefe Inmediato', profile['jefe_inmediato'] ?? '---', 'Jefe Directo'),
                    ],
                  ),
                  pw.SizedBox(height: 50),
                  // Footer Note
                  pw.Text(
                    'Nota: Esta solicitud deberá ser entregada con las firmas correspondientes a Desarrollo Humano con al menos 3 días de anticipación a la fecha en que se tomarán los días de vacaciones, de no hacerse así, la solicitud NO procederá.',
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Show preview/print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'solicitud_vacaciones_${fullName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _dateColumn(String label, String date) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(date, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  static pw.Widget _signatureBox(String role, String name, String position) {
    return pw.Column(
      children: [
        pw.Text(role, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 60),
        pw.Container(width: 200, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 5),
        pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.Text(position, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }
}
