import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
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

    final res =
        await http.get(Uri.parse('http://127.0.0.1:8000/grupos'));

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
        title: const Text('Cursos disponibles'),
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
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPinPage(),
                ),
              );
              cargarCursos(); // 🔁 refresca cupos
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
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(c['curso']),
                    subtitle:
                        Text('${c['horario']} • Inicio ${c['inicio']}'),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          hayCupo
                              ? 'Cupos: $cupos'
                              : 'Cupo lleno',
                          style: TextStyle(
                            color:
                                hayCupo ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
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
  Map<String, dynamic>? resultado;
  String? error;

  Future<void> consultar() async {
    setState(() {
      resultado = null;
      error = null;
    });

    final codigo = codigoCtrl.text.trim().toUpperCase();

    final res = await http.get(
      Uri.parse(
          'http://127.0.0.1:8000/matricula/consultar/$codigo'),
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
                labelText: 'Código',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: consultar,
              child: const Text('Consultar'),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (resultado != null)
              Card(
                margin: const EdgeInsets.only(top: 20),
                child: ListTile(
                  title: Text(resultado!['estudiante']),
                  subtitle: Text(resultado!['curso']),
                  trailing: Text(
                    resultado!['estado'],
                    style: TextStyle(
                      color: resultado!['estado'] == 'aprobada'
                          ? Colors.green
                          : resultado!['estado'] == 'rechazada'
                              ? Colors.red
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
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
      Uri.parse('http://127.0.0.1:8000/matricula'),
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
        title: const Text('Matrícula recibida'),
        content: SelectableText(data['codigo']),
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
            Text(widget.curso),
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

class AdminPinPage extends StatelessWidget {
  const AdminPinPage({super.key});

  static const pin = '289710';

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin PIN')),
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
            ElevatedButton(
              onPressed: () {
                if (ctrl.text == pin) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const AdminMatriculasPage(),
                    ),
                  );
                }
              },
              child: const Text('Entrar'),
            ),
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
    final res = await http.get(
      Uri.parse('http://127.0.0.1:8000/admin/matriculas'),
    );
    setState(() {
      matriculas = json.decode(res.body);
    });
  }

  Future<void> aprobar(String id) async {
    await http.post(
      Uri.parse('http://127.0.0.1:8000/admin/aprobar/$id'),
    );
    cargar(); // 🔁 refresca estado
  }

  Future<void> rechazar(String id) async {
    await http.post(
      Uri.parse('http://127.0.0.1:8000/admin/rechazar/$id'),
    );
    cargar(); // 🔁 refresca estado y cupos
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
              padding: const EdgeInsets.all(12),
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
                        onPressed: () => aprobar(m['id']),
                        child: const Text('Aprobar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => rechazar(m['id']),
                        child: const Text('Rechazar'),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.attach_file),
                        onPressed: () async {
                          final url =
                              'http://127.0.0.1:8000/admin/comprobante/${m['id']}';
                          await launchUrl(Uri.parse(url));
                        },
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
