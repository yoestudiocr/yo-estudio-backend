import 'dart:typed_data';

class PickedComprobante {
  final Uint8List bytes;
  final String name;

  PickedComprobante(this.bytes, this.name);
}

Future<PickedComprobante?> pickComprobanteImage() async {
  // En web se reemplaza automáticamente por web_file_picker.dart
  throw UnsupportedError(
    'Selector de archivos no disponible en esta plataforma',
  );
}
