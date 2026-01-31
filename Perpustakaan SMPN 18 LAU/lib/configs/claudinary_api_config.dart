import 'package:flutter_dotenv/flutter_dotenv.dart';

class ClaudinaryApiConfig {
  static String _clean(String? v) {
    if (v == null) return '';
    var s = v.trim();
    // remove surrounding single or double quotes if present
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1);
    }
    return s.trim();
  }

  static get cloudinarycloudname => _clean(dotenv.env['CLOUDINARY_CLOUD_NAME']);
  static get clodinaryuploadpreset =>
      _clean(dotenv.env['CLOUDINARY_UPLOAD_PRESET']);
  static get cloudinaryApiKey => _clean(dotenv.env['CLOUDINARY_API_KEY']);
  static get cloudinaryApiSecret => _clean(dotenv.env['CLOUDINARY_API_SECRET']);
  // Allow client-side admin delete (unsafe). Default: false. Set to 'true' in .env to enable (not recommended).
  static bool get allowClientDelete {
    final v = _clean(dotenv.env['ALLOW_CLIENT_DELETE']);
    if (v.isEmpty) return false;
    return v.toLowerCase() == 'true' || v == '1';
  }
}
