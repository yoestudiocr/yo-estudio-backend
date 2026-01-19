import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 🔗 Backend en Render
const String BASE_URL = 'https://yo-estudio-backend.onrender.com';

void main() {
  runApp(const YoEstudioApp());
}

/* ================= APP ================= */

class YoEstudioApp extends StatelessWidget {
  const YoEstudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yo Estudio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
      ),
      home: const CursosPage(),
    );
  }
}

/* ================= CURSOS ================= */

class CursosPage extends StatefulWidget {
  const CursosPage({super.key});

  @override
  State<CursosPage> createState() => _CursosPageState();
}

class _CursosPageState extends State<CursosPage> {
  List cursos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarCursos();
  }

  Future<void> cargarCursos() async {
    setState(() => cargando = true);
    final res = await http.get(Uri.parse('$BASE_URL/grupos'));
    if (res.statusCode == 200) {
      setState(() {
        cursos = json.decode(res.body);
        cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursos 📚'),
        actions: [
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConsultarMatriculaPage(),
                ),
              );
              cargarCursos();
            },
            child: const Text(
              'Consultar matrícula',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPinPage()),
              );
            },
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: cursos.length,
              itemBuilder: (_, i) {
                final c = cursos[i];
                final cupos =
                    c['cupos_max'] - c['cupos_ocupados'];
                final hayCupo = cupos > 0;

                return Card(
                  margin: const EdgeInsets.all(14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['curso'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(c['horario']),
                        const SizedBox(height: 10),
                        Text(
                          hayCupo
                              ? 'Cupos disponibles: $cupos'
                              : 'Cupo lleno',
                          style: TextStyle(
                            color:
                                hayCupo ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: hayCupo
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MatriculaPage(
                                          curso: c['curso'],
                                          grupoId: c['id'],
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            child: const Text('Matricularme'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/* ================= CONSULTAR MATRÍCULA ================= */

class ConsultarMatriculaPage extends StatefulWidget {
  const ConsultarMatriculaPage({super.key});

  @override
  State<ConsultarMatriculaPage> createState() =>
      _ConsultarMatriculaPageState();
}

class _ConsultarMatriculaPageState
    extends State<ConsultarMatriculaPage> {
  final codigoCtrl = TextEditingController();
  Map<String, dynamic>? resultado;
  String? error;

  Future<void> consultar() async {
    setState(() {
      resultado = null;
      error = null;
    });

    final res = await http.get(
      Uri.parse('$BASE_URL/matricula/consultar/${codigoCtrl.text.trim()}'),
    );

    if (res.statusCode == 200) {
      setState(() {
        resultado = json.decode(res.body);
      });
    } else {
      setState(() {
        error = 'Código no encontrado';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultar matrícula')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: codigoCtrl,
              decoration: const InputDecoration(
                labelText: 'Código de matrícula',
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: consultar,
              child: const Text('Consultar'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child:
                    Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (resultado != null)
              Card(
                margin: const EdgeInsets.only(top: 20),
                child: ListTile(
                  title: Text(resultado!['estudiante']),
                  subtitle: Text(resultado!['curso']),
                  trailing: Text(
                    resultado!['estado'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: resultado!['estado'] == 'aprobada'
                          ? Colors.green
                          : resultado!['estado'] == 'rechazada'
                              ? Colors.red
                              : Colors.orange,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/* ================= MATRÍCULA ================= */

class MatriculaPage extends StatefulWidget {
  final String curso;
  final String grupoId;

  const MatriculaPage({
    super.key,
    required this.curso,
    required this.grupoId,
  });

  @override
  State<MatriculaPage> createState() => _MatriculaPageState();
}

class _MatriculaPageState extends State<MatriculaPage> {
  final estudianteCtrl = TextEditingController();
  final encargadoCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();

  Uint8List? comprobanteBytes;
  String? comprobanteNombre;

  bool enviando = false;

  /* --------- PICK FILE WEB (FUNCIONA EN CEL) --------- */
  Future<void> seleccionarComprobante() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();

    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((event) {
        setState(() {
          comprobanteBytes = reader.result as Uint8List;
          comprobanteNombre = file.name;
        });
      });
    });
  }

  /* --------- ENVIAR MATRÍCULA --------- */
  Future<void> enviarMatricula() async {
    if (estudianteCtrl.text.isEmpty ||
        encargadoCtrl.text.isEmpty ||
        telefonoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá todos los datos')),
      );
      return;
    }

    if (comprobanteBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjuntá el comprobante de pago')),
      );
      return;
    }

    setState(() => enviando = true);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$BASE_URL/matricula'),
    );

    request.fields.addAll({
      'estudiante': estudianteCtrl.text,
      'encargado': encargadoCtrl.text,
      'telefono': telefonoCtrl.text,
      'grupo_id': widget.grupoId,
    });

    request.files.add(
      http.MultipartFile.fromBytes(
        'comprobante',
        comprobanteBytes!,
        filename: comprobanteNombre ?? 'comprobante.jpg',
      ),
    );

    final response = await request.send();
    final data =
        json.decode(await response.stream.bytesToString());

    setState(() => enviando = false);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text(
          '¡Gracias por tu matrícula! 📚💙',
          style: TextStyle(
            color: Color(0xFF1E3A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu matrícula quedó registrada correctamente.\n\n'
              '📌 El cupo se mantiene reservado mientras '
              'verificamos el pago.',
            ),
            const SizedBox(height: 16),
            const Text(
              '🔑 Código de matrícula:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            SelectableText(
              data['codigo'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Podés consultar el estado de tu matrícula '
              'en la página principal usando este código.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /* --------- CAJITA INFO CUTE --------- */
  Widget cajaInfo(IconData icon, String texto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matrícula')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.curso,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 20),

          /* --------- DATOS --------- */
          TextField(
            controller: estudianteCtrl,
            decoration:
                const InputDecoration(labelText: 'Nombre del estudiante'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: encargadoCtrl,
            decoration:
                const InputDecoration(labelText: 'Nombre del encargado'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration:
                const InputDecoration(labelText: 'Teléfono del encargado'),
          ),

          const SizedBox(height: 24),

          /* --------- INFO PAGO --------- */
          cajaInfo(
            Icons.info_outline,
            '📌 Para completar la matrícula se requiere realizar '
            'el pago del primer mes.',
          ),
          cajaInfo(
            Icons.payments_outlined,
            '💰 Costo: ₡20 000 colones.\n\n'
            'La matrícula quedará pendiente hasta que '
            'el pago sea verificado.',
          ),
          cajaInfo(
            Icons.account_balance,
            '💳 Información de pago:\n\n'
            'Nombre: Grettel Franciny Murillo Cerdas\n\n'
            'SINPE Móvil: 8426 9666\n'
            'Cuenta BAC: 952676674\n'
            'Cuenta IBAN: CR28010200009526766748',
          ),

          const SizedBox(height: 20),

          /* --------- COMPROBANTE --------- */
          ElevatedButton.icon(
            icon: Icon(
              comprobanteBytes != null
                  ? Icons.check_circle
                  : Icons.upload_file,
            ),
            label: Text(
              comprobanteBytes != null
                  ? 'Comprobante adjunto ✔'
                  : 'Adjuntar comprobante',
            ),
            onPressed: seleccionarComprobante,
          ),

          const SizedBox(height: 24),

          /* --------- ENVIAR --------- */
          ElevatedButton(
            onPressed: enviando ? null : enviarMatricula,
            child: enviando
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Enviar matrícula'),
          ),
        ],
      ),
    );
  }
}

/* ================= ADMIN PIN ================= */

class AdminPinPage extends StatefulWidget {
  const AdminPinPage({super.key});

  @override
  State<AdminPinPage> createState() => _AdminPinPageState();
}

class _AdminPinPageState extends State<AdminPinPage> {
  final pinCtrl = TextEditingController();
  String? error;

  static const String adminPin = '289710';

  void validarPin() {
    if (pinCtrl.text.trim() == adminPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminMatriculasPage(),
        ),
      );
    } else {
      setState(() {
        error = 'PIN incorrecto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso administrador')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Ingrese el PIN de administrador',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: validarPin,
                child: const Text('Entrar'),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
/* ================= ADMIN PANEL ================= */

class AdminMatriculasPage extends StatefulWidget {
  const AdminMatriculasPage({super.key});

  @override
  State<AdminMatriculasPage> createState() =>
      _AdminMatriculasPageState();
}

class _AdminMatriculasPageState
    extends State<AdminMatriculasPage> {
  Map<String, dynamic> matriculas = {};
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarMatriculas();
  }

  Future<void> cargarMatriculas() async {
    setState(() => cargando = true);

    final res =
        await http.get(Uri.parse('$BASE_URL/admin/matriculas'));

    if (res.statusCode == 200) {
      setState(() {
        matriculas = json.decode(res.body);
        cargando = false;
      });
    }
  }

  Future<void> aprobar(String id) async {
    await http.post(
      Uri.parse('$BASE_URL/admin/aprobar/$id'),
    );
    cargarMatriculas();
  }

  Future<void> rechazar(String id) async {
    await http.post(
      Uri.parse('$BASE_URL/admin/rechazar/$id'),
    );
    cargarMatriculas();
  }

  Color colorEstado(String estado) {
    switch (estado) {
      case 'aprobada':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: matriculas.entries.map((entry) {
                final m = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['estudiante'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Encargado: ${m['encargado']}'),
                        Text('Teléfono: ${m['telefono']}'),
                        const SizedBox(height: 6),
                        Text('Código: ${m['codigo']}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Estado: ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              m['estado'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    colorEstado(m['estado']),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        /// 👇 AQUÍ ESTABA EL PROBLEMA
                        if (m['estado'] == 'pendiente')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    aprobar(m['id']),
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.green,
                                  foregroundColor:
                                      Colors.white,
                                ),
                                child:
                                    const Text('Aprobar'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () =>
                                    rechazar(m['id']),
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor:
                                      Colors.white,
                                ),
                                child:
                                    const Text('Rechazar'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

