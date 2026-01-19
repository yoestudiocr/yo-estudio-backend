// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'file_picker_stub.dart';

Future<PickedComprobante?> pickComprobanteImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  input.click();

  // Espera a que el usuario seleccione archivo
  await input.onChange.first;

  final file = input.files?.isNotEmpty == true
      ? input.files!.first
      : null;

  if (file == null) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);

  await reader.onLoadEnd.first;

  final result = reader.result;
  if (result is! ByteBuffer) return null;

  return PickedComprobante(
    result.asUint8List(),
    file.name,
  );
}
