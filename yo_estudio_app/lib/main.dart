import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const API = 'https://yo-estudio-backend.onrender.com';
const adminPin = '289710';

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
        scaffoldBackgroundColor: const Color(0xFFF5F8FF),
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
    final res = await http.get(Uri.parse('$API/grupos'));
    if (res.statusCode == 200) {
      cursos = json.decode(res.body);
    }
    setState(() => cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cursos disponibles'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConsultarMatriculaPage(),
              ),
            ),
            child: const Text(
              'Consultar matrícula',
              style: TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminPinPage()),
            ),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: cursos.length,
              itemBuilder: (_, i) {
                final c = cursos[i];
                final cupos = c['cupos_disponibles'];

                return Card(
                  margin: const EdgeInsets.all(12),
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
                        const SizedBox(height: 6),
                        Text(
                          cupos > 0
                              ? 'Cupos disponibles: $cupos'
                              : 'Cupo lleno',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cupos > 0
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: cupos > 0
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MatriculaPage(
                                          curso: c['curso'],
                                          grupoId: c['id'],
                                        ),
                                      ),
                                    )
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

/* ================= CONSULTAR ================= */

class ConsultarMatriculaPage extends StatefulWidget {
  const ConsultarMatriculaPage({super.key});

  @override
  State<ConsultarMatriculaPage> createState() =>
      _ConsultarMatriculaPageState();
}

class _ConsultarMatriculaPageState
    extends State<ConsultarMatriculaPage> {
  final codigoCtrl = TextEditingController();
  Map<String, dynamic>? data;
  String? error;

  Future<void> consultar() async {
    error = null;
    data = null;
    setState(() {});
    final codigo = codigoCtrl.text.trim().toUpperCase();
    final res =
        await http.get(Uri.parse('$API/matricula/consultar/$codigo'));
    if (res.statusCode == 200) {
      data = json.decode(res.body);
    } else {
      error = 'Código no encontrado';
    }
    setState(() {});
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
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: consultar,
              child: const Text('Consultar'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (data != null)
              Card(
                margin: const EdgeInsets.only(top: 20),
                child: ListTile(
                  title: Text(data!['estudiante']),
                  subtitle: Text(data!['curso']),
                  trailing: Text(
                    data!['estado'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: data!['estado'] == 'aprobada'
                          ? Colors.green
                          : data!['estado'] == 'rechazada'
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

  const MatriculaPage(
      {super.key, required this.curso, required this.grupoId});

  @override
  State<MatriculaPage> createState() => _MatriculaPageState();
}

class _MatriculaPageState extends State<MatriculaPage> {
  final estudianteCtrl = TextEditingController();
  final encargadoCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();
  File? comprobante;

  Future<void> enviar() async {
    if (comprobante == null) return;

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$API/matricula'),
    );

    req.fields.addAll({
      'estudiante': estudianteCtrl.text,
      'encargado': encargadoCtrl.text,
      'telefono': telefonoCtrl.text,
      'grupo_id': widget.grupoId,
    });

    req.files.add(
      await http.MultipartFile.fromPath(
        'comprobante',
        comprobante!.path,
      ),
    );

    final res = await req.send();
    final data =
        json.decode(await res.stream.bytesToString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Matrícula enviada 💙'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Guarde este código:'),
            const SizedBox(height: 8),
            SelectableText(
              data['codigo'],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matrícula')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(widget.curso,
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
            TextField(
                controller: estudianteCtrl,
                decoration:
                    const InputDecoration(labelText: 'Estudiante')),
            TextField(
                controller: encargadoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Encargado')),
            TextField(
                controller: telefonoCtrl,
                decoration:
                    const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final r =
                    await FilePicker.platform.pickFiles();
                if (r != null) {
                  setState(() {
                    comprobante =
                        File(r.files.single.path!);
                  });
                }
              },
              child: const Text('Adjuntar comprobante'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: enviar,
              child: const Text('Enviar matrícula'),
            ),
          ],
        ),
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
  final ctrl = TextEditingController();
  String? error;

  void validar() {
    if (ctrl.text == adminPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminMatriculasPage(),
        ),
      );
    } else {
      setState(() => error = 'PIN incorrecto');
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
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'PIN'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: validar,
              child: const Text('Entrar'),
            ),
            if (error != null)
              Text(error!,
                  style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

/* ================= ADMIN ================= */

class AdminMatriculasPage extends StatefulWidget {
  const AdminMatriculasPage({super.key});

  @override
  State<AdminMatriculasPage> createState() =>
      _AdminMatriculasPageState();
}

class _AdminMatriculasPageState
    extends State<AdminMatriculasPage> {
  Map<String, dynamic> matriculas = {};

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    final res =
        await http.get(Uri.parse('$API/admin/matriculas'));
    matriculas = json.decode(res.body);
    setState(() {});
  }

  Future<void> abrirComprobante(String id) async {
    final url = Uri.parse('$API/admin/comprobante/$id');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: matriculas.entries.map((e) {
          final m = e.value;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['estudiante'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  Text('Estado: ${m['estado']}'),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await http.post(Uri.parse(
                              '$API/admin/aprobar/${m['id']}'));
                          cargar();
                        },
                        child: const Text('Aprobar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await http.post(Uri.parse(
                              '$API/admin/rechazar/${m['id']}'));
                          cargar();
                        },
                        child: const Text('Rechazar'),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.attach_file),
                        onPressed: () =>
                            abrirComprobante(m['id']),
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
