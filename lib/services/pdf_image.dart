import 'dart:convert';
import 'dart:typed_data';

/// A one-page PDF holding one picture (the certificate), A4 landscape.
/// [zip] compresses the pixels when the platform can (null = store as is).
Uint8List imagePdf(int w, int h, Uint8List rgba, List<int>? Function(List<int>) zip) {
  final rgb = Uint8List(w * h * 3);
  for (var i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
    rgb[j] = rgba[i];
    rgb[j + 1] = rgba[i + 1];
    rgb[j + 2] = rgba[i + 2];
  }
  final z = zip(rgb);
  final data = z ?? rgb;
  const pw = 842.0;
  final ph = pw * h / w;
  final out = BytesBuilder();
  final offsets = <int>[];
  void put(String s) => out.add(latin1.encode(s));
  void obj(String s) {
    offsets.add(out.length);
    put(s);
  }

  put('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n');
  obj('1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n');
  obj('2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n');
  obj('3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 ${pw.toStringAsFixed(2)} ${ph.toStringAsFixed(2)}]'
      '/Resources<</XObject<</Im0 4 0 R>>>>/Contents 5 0 R>>endobj\n');
  offsets.add(out.length);
  put('4 0 obj<</Type/XObject/Subtype/Image/Width $w/Height $h/ColorSpace/DeviceRGB/BitsPerComponent 8'
      '${z != null ? '/Filter/FlateDecode' : ''}/Length ${data.length}>>stream\n');
  out.add(data);
  put('\nendstream endobj\n');
  final content = 'q ${pw.toStringAsFixed(2)} 0 0 ${ph.toStringAsFixed(2)} 0 0 cm /Im0 Do Q';
  obj('5 0 obj<</Length ${content.length}>>stream\n$content\nendstream endobj\n');
  final xref = out.length;
  put('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    put('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  put('trailer<</Size ${offsets.length + 1}/Root 1 0 R>>\nstartxref\n$xref\n%%EOF\n');
  return out.toBytes();
}
