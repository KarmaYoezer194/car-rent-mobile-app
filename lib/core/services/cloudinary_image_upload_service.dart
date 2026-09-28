import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/cloudinary_config.dart';
import 'image_upload_service.dart';

/// Uploads images to Cloudinary's free tier using an unsigned upload
/// preset — no API secret needed on the client, which is what makes this
/// safe to call directly from the app instead of through a backend.
class CloudinaryImageUploadService implements ImageUploadService {
  @override
  Future<String> uploadImage(
    Uint8List bytes, {
    required String filename,
    required String folder,
    UploadProgressCallback? onProgress,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );

    final request = _ProgressMultipartRequest('POST', uri, onProgress: onProgress)
      ..fields['upload_preset'] = CloudinaryConfig.unsignedUploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw ImageUploadException(
        'Cloudinary upload failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = body['secure_url'] as String?;
    if (url == null) {
      throw const ImageUploadException('Cloudinary response was missing secure_url.');
    }
    return url;
  }
}

/// [http.MultipartRequest] that reports how much of its body has been
/// handed to the client. On Android/iOS/desktop that tracks the socket
/// write closely; on web the browser client buffers the whole body first,
/// so progress jumps straight to 1.0 and the UI shows "finishing" while the
/// request is actually in flight.
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {this.onProgress});

  final UploadProgressCallback? onProgress;

  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final callback = onProgress;
    if (callback == null) return stream;

    final total = contentLength;
    var sent = 0;
    return http.ByteStream(stream.transform(
      StreamTransformer.fromHandlers(handleData: (chunk, sink) {
        sent += chunk.length;
        callback(total <= 0 ? 0 : (sent / total).clamp(0, 1).toDouble());
        sink.add(chunk);
      }),
    ));
  }
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);
  final String message;

  @override
  String toString() => message;
}
