import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Logo "G" oficial de Google (multicolor), renderizado desde el SVG oficial.
class GoogleGIcon extends StatelessWidget {
  final double size;

  const GoogleGIcon({super.key, this.size = 22});

  static const String _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
  <path fill="#4285F4" d="M23.52 12.18c0-.85-.08-1.68-.22-2.49H12.3v5.02h6.35c-.3 1.6-1.2 2.96-2.56 3.87v3.22h4.1c2.42-2.23 3.55-5.5 3.55-9.62z"/>
  <path fill="#34A853" d="M12.3 23.7c3.25 0 5.96-1.07 7.96-2.9l-4.1-3.22c-1.11.72-2.54 1.15-3.86 1.15-2.97 0-5.48-2-6.37-4.7H1.77v3.32c1.97 3.9 6.02 6.36 10.53 6.36z"/>
  <path fill="#FBBC05" d="M5.93 15.05c-.25-.72-.39-1.49-.39-2.3s.14-1.57.39-2.29V7.15H1.77a11.86 11.86 0 0 0 0 10.26l4.16-3.36z"/>
  <path fill="#EA4335" d="M12.3 6.03c1.76 0 3.34.61 4.57 1.8l3.43-3.43C18.27 2.7 15.53 1.55 12.3 1.55c-4.5 0-8.56 2.44-10.53 6.34l4.16 3.32c.89-2.7 3.4-4.7 6.37-4.7z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
    );
  }
}
