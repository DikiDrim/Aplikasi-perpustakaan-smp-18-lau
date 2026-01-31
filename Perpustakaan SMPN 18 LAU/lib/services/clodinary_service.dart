import '../configs/claudinary_api_config.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ClodinaryService {
  final _cloudinary = CloudinaryPublic(
    ClaudinaryApiConfig.cloudinarycloudname,
    ClaudinaryApiConfig.clodinaryuploadpreset,
  );

  /// Menghapus image di Cloudinary via Admin API menggunakan publicId.
  /// WARNING: This method membutuhkan API Secret di sisi klien — pastikan
  /// Anda paham risikonya. Method ini melakukan HTTP POST ke endpoint
  /// https://api.cloudinary.com/v1_1/{cloud_name}/resources/image/upload
  Future<bool> deleteImageByPublicId(String publicId) async {
    final cloudName = ClaudinaryApiConfig.cloudinarycloudname;
    final apiKey = ClaudinaryApiConfig.cloudinaryApiKey;
    final apiSecret = ClaudinaryApiConfig.cloudinaryApiSecret;

    if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      throw 'Cloudinary credentials tidak lengkap';
    }

    // Build basic auth header (don't print secrets)
    final credentials = base64Encode(utf8.encode('$apiKey:$apiSecret'));

    Future<http.Response> _postForm(String path, Map<String, String> body) {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName$path');
      // safe log
      print('Cloudinary: POST $url');
      return http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
    }

    // Safe debug info (avoid printing secrets)
    print(
      'Cloudinary debug: cloudName=$cloudName, apiKeyLen=${apiKey.length}, apiSecretLen=${apiSecret.length}',
    );

    // 1) Try deleting as image
    try {
      final resp1 = await _postForm('/image/destroy', {
        'public_id': publicId,
        'invalidate': 'true',
      });

      if (resp1.statusCode >= 200 && resp1.statusCode < 300) {
        print('Cloudinary: /image/destroy successful (${resp1.statusCode})');
        return true;
      }

      // 2) Try deleting as raw (PDF uploads often land here)
      final respRaw = await _postForm('/raw/destroy', {
        'public_id': publicId,
        'invalidate': 'true',
      });

      if (respRaw.statusCode >= 200 && respRaw.statusCode < 300) {
        print('Cloudinary: /raw/destroy successful (${respRaw.statusCode})');
        return true;
      }

      // 3) Fallback: bulk delete for image
      final resp2 = await _postForm('/resources/image/destroy', {
        'public_ids[]': publicId,
      });

      if (resp2.statusCode >= 200 && resp2.statusCode < 300) {
        print(
          'Cloudinary: /resources/image/destroy successful (${resp2.statusCode})',
        );
        return true;
      }

      // 4) Fallback: bulk delete for raw
      final respRawBulk = await _postForm('/resources/raw/destroy', {
        'public_ids[]': publicId,
      });

      if (respRawBulk.statusCode >= 200 && respRawBulk.statusCode < 300) {
        print(
          'Cloudinary: /resources/raw/destroy successful (${respRawBulk.statusCode})',
        );
        return true;
      }

      // Neither worked — log concise info for debugging
      final previews =
          [
            resp1.body,
            respRaw.body,
            resp2.body,
            respRawBulk.body,
          ].where((b) => b.isNotEmpty).toList();
      final preview = previews.isNotEmpty ? previews.first : '';
      final bodyPreview =
          (preview.length > 800) ? preview.substring(0, 800) + '...' : preview;
      print(
        'Cloudinary delete failed (codes: ${resp1.statusCode}, ${respRaw.statusCode}, ${resp2.statusCode}, ${respRawBulk.statusCode}): $bodyPreview',
      );
      return false;
    } catch (e) {
      print('Cloudinary delete exception: $e');
      return false;
    }
  }

  Future<Map<String, String>?> uploadImageToCloudinary(
    XFile imageFile,
    String? existingPublicId,
  ) async {
    try {
      if (imageFile.path.isEmpty) {
        throw 'Image file path is empty.';
      }

      final fileToUpload = CloudinaryFile.fromFile(
        imageFile.path,
        resourceType: CloudinaryResourceType.Image,
        // ⚡ Jika ada publicId lama → timpa file lama
        publicId: existingPublicId,
      );

      final response = await _cloudinary.uploadFile(fileToUpload);

      return {'url': response.secureUrl, 'publicId': response.publicId};
    } on CloudinaryException catch (e) {
      print('Cloudinary error: ${e.message}');
      throw 'Gagal mengunggah foto ke Cloudinary: ${e.message}';
    } catch (e) {
      print('Upload error: $e');
      throw 'Terjadi kesalahan saat mengunggah foto: $e';
    }
  }

  /// Upload file PDF ke Cloudinary
  /// Mengembalikan map dengan 'url' dan 'publicId'
  Future<Map<String, String>?> uploadPdfToCloudinary(
    File pdfFile,
    String? existingPublicId,
  ) async {
    try {
      if (!await pdfFile.exists()) {
        throw 'File PDF tidak ditemukan.';
      }

      // Bersihkan publicId dari karakter yang tidak valid
      String? cleanPublicId = existingPublicId;
      if (cleanPublicId != null) {
        // Hapus karakter yang tidak valid untuk Cloudinary public_id
        // Cloudinary public_id hanya boleh mengandung: a-z, A-Z, 0-9, /, _, -
        cleanPublicId = cleanPublicId.replaceAll(
          RegExp(r'[^a-zA-Z0-9/_\-]'),
          '_',
        );
      }

      // Cloudinary bisa handle PDF sebagai Image resource type
      // Ini lebih kompatibel dengan upload preset unsigned
      final fileToUpload = CloudinaryFile.fromFile(
        pdfFile.path,
        resourceType:
            CloudinaryResourceType
                .Auto, // PDF sebagai image (Cloudinary support ini)
        publicId: cleanPublicId,
      );

      final response = await _cloudinary.uploadFile(fileToUpload);

      if (response.secureUrl.isEmpty) {
        throw 'URL tidak diterima dari Cloudinary';
      }

      return {'url': response.secureUrl, 'publicId': response.publicId};
    } on CloudinaryException catch (e) {
      print('Cloudinary PDF upload error: ${e.message}');
      print('Error details: ${e.toString()}');

      // Berikan pesan error yang lebih informatif
      String errorMsg = 'Gagal mengunggah PDF ke Cloudinary';
      if (e.message != null && e.message!.isNotEmpty) {
        errorMsg += ': ${e.message}';
      }

      throw errorMsg;
    } catch (e) {
      print('PDF Upload error: $e');
      print('Error type: ${e.runtimeType}');

      // Handle DioException atau error HTTP lainnya (400, 401, dll)
      final errorStr = e.toString();
      if (errorStr.contains('400') || errorStr.contains('bad response')) {
        throw 'Error 400: Request tidak valid.\n\n'
            'Kemungkinan penyebab:\n'
            '1. Upload Preset tidak dikonfigurasi untuk menerima file PDF\n'
            '2. File PDF terlalu besar (melebihi batas upload preset)\n'
            '3. Upload Preset tidak unsigned atau tidak dikonfigurasi dengan benar\n\n'
            'Solusi:\n'
            '1. Buka Cloudinary Console > Settings > Upload\n'
            '2. Edit Upload Preset yang digunakan\n'
            '3. Pastikan "Signing mode" = "Unsigned" atau "Authenticated"\n'
            '4. Pastikan tidak ada batasan file type yang memblokir PDF\n'
            '5. Pastikan "Allowed formats" termasuk PDF atau kosongkan untuk allow all';
      } else if (errorStr.contains('401') ||
          errorStr.contains('unauthorized')) {
        throw 'Error 401: Tidak memiliki izin.\n'
            'Pastikan Upload Preset dikonfigurasi dengan benar di Cloudinary Console.';
      } else if (errorStr.contains('413') || errorStr.contains('too large')) {
        throw 'Error: File terlalu besar.\n'
            'Ukuran file PDF melebihi batas yang diizinkan oleh Upload Preset.';
      }

      throw 'Terjadi kesalahan saat mengunggah PDF: $e';
    }
  }

  /// Upload PDF dari bytes (untuk Web) ke Cloudinary
  Future<Map<String, String>?> uploadPdfBytesToCloudinary(
    Uint8List bytes,
    String fileName,
    String? existingPublicId,
  ) async {
    try {
      if (bytes.isEmpty) {
        throw 'Data file kosong.';
      }

      final cloudName = ClaudinaryApiConfig.cloudinarycloudname;
      final uploadPreset = ClaudinaryApiConfig.clodinaryuploadpreset;
      if (cloudName.isEmpty || uploadPreset.isEmpty) {
        throw 'Konfigurasi Cloudinary tidak lengkap (cloud name/preset).';
      }

      String? cleanPublicId = existingPublicId;
      if (cleanPublicId != null) {
        cleanPublicId = cleanPublicId.replaceAll(
          RegExp(r'[^a-zA-Z0-9/_\-]'),
          '_',
        );
      }

      // Ensure filename has .pdf extension (Cloudinary may rely on this)
      String filenameNormalized = fileName;
      if (!filenameNormalized.toLowerCase().endsWith('.pdf')) {
        filenameNormalized = '$filenameNormalized.pdf';
      }

      // Log concise diagnostic info to help debugging invalid-file errors
      final previewHex = bytes
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      print(
        'Cloudinary upload (bytes): filename=$filenameNormalized, size=${bytes.length}, first8=$previewHex',
      );

      Future<http.StreamedResponse> doUpload(String path) {
        final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName$path',
        );
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = uploadPreset;

        // For raw uploads (PDF), explicitly set resource_type
        request.fields['resource_type'] = 'raw';

        if (cleanPublicId != null) {
          request.fields['public_id'] = cleanPublicId;
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filenameNormalized,
            contentType: http_parser.MediaType('application', 'pdf'),
          ),
        );

        return request.send();
      }

      // Force raw upload for PDFs: more reliable for binary file types
      final resp = await doUpload('/raw/upload');
      final body = await resp.stream.bytesToString();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final url = decoded['secure_url'] as String?;
        final publicId = decoded['public_id'] as String?;
        if (url == null || url.isEmpty) {
          throw 'URL tidak diterima dari Cloudinary (raw)';
        }
        print(
          'Cloudinary raw upload successful: public_id=${publicId ?? cleanPublicId}',
        );
        return {'url': url, 'publicId': publicId ?? cleanPublicId ?? ''};
      }

      print('Cloudinary raw upload failed (${resp.statusCode}): $body');
      throw 'Upload gagal (${resp.statusCode}): $body';
    } catch (e) {
      throw 'Gagal mengunggah PDF (bytes): $e';
    }
  }

  /// Hapus file PDF dari Cloudinary menggunakan publicId
  Future<bool> deletePdfByPublicId(String publicId) async {
    final cloudName = ClaudinaryApiConfig.cloudinarycloudname;
    final apiKey = ClaudinaryApiConfig.cloudinaryApiKey;
    final apiSecret = ClaudinaryApiConfig.cloudinaryApiSecret;

    if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
      throw 'Cloudinary credentials tidak lengkap';
    }

    // Build basic auth header
    final credentials = base64Encode(utf8.encode('$apiKey:$apiSecret'));

    Future<http.Response> _postForm(String path, Map<String, String> body) {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName$path');
      return http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );
    }

    try {
      // Untuk raw file (PDF), gunakan endpoint /raw/destroy
      final resp = await _postForm('/raw/destroy', {
        'public_id': publicId,
        'invalidate': 'true',
      });

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        print('Cloudinary: /raw/destroy successful (${resp.statusCode})');
        return true;
      }

      print(
        'Cloudinary delete PDF failed (code: ${resp.statusCode}): ${resp.body}',
      );
      return false;
    } catch (e) {
      print('Cloudinary delete PDF exception: $e');
      return false;
    }
  }
}
