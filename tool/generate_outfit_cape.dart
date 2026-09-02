import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Genera `assets/images/outfit_capa_heroe.png`: una capa roja circular que se
/// dibuja como overlay encima del gato en `NekoCatMascot`.
void main() {
  const size = 512;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  const cx = size / 2.0;
  const cy = size / 2.0;
  final red = img.ColorRgba8(213, 43, 43, 255);
  final redDark = img.ColorRgba8(148, 24, 24, 255);

  double rad(double deg) => deg * pi / 180.0;
  img.Point pt(double deg, double r) =>
      img.Point(cx + r * cos(rad(deg)), cy - r * sin(rad(deg)));

  const start = 38.0;
  const end = 142.0;
  const steps = 56;

  List<img.Point> arc(double rOuter, double rInner) {
    final pts = <img.Point>[];
    for (var i = 0; i <= steps; i++) {
      pts.add(pt(start + (end - start) * i / steps, rOuter));
    }
    for (var i = steps; i >= 0; i--) {
      pts.add(pt(start + (end - start) * i / steps, rInner));
    }
    return pts;
  }

  // Borde oscuro (anillo exterior)
  img.fillPolygon(image, vertices: arc(254, 170), color: redDark);
  // Capa roja (anillo interior)
  img.fillPolygon(image, vertices: arc(246, 184), color: red);

  // Alas laterales que cuelgan hacia abajo
  final p1i = pt(start, 184);
  final p1o = pt(start, 246);
  final p2i = pt(end, 184);
  final p2o = pt(end, 246);

  // Ala izquierda
  img.fillPolygon(
    image,
    vertices: [p1i, p1o, img.Point(150, 408), img.Point(120, 330)],
    color: red,
  );
  // Ala derecha (espejo)
  img.fillPolygon(
    image,
    vertices: [p2i, p2o, img.Point(362, 408), img.Point(392, 330)],
    color: red,
  );

  final out = File('assets/images/outfit_capa_heroe.png');
  out.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('Generado: ${out.path}');
}
