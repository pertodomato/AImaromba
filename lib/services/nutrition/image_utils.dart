import 'dart:typed_data';
import 'package:image/image.dart' as img;

Future<Uint8List> downsizeJpeg(Uint8List bytes, {int maxDim = 1024, int quality = 85}) async {
  final src = img.decodeImage(bytes);
  if (src == null) return bytes;
  int w = src.width, h = src.height;
  if (w<=maxDim && h<=maxDim) {
    return Uint8List.fromList(img.encodeJpg(src, quality: quality));
  }
  final scale = (w>h) ? maxDim/w : maxDim/h;
  final dst = img.copyResize(src, width: (w*scale).round(), height: (h*scale).round());
  return Uint8List.fromList(img.encodeJpg(dst, quality: quality));
}
