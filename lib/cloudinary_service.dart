import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class CloudinaryService {
  static const String cloudName =
      'de7izh7qg'; // Your Cloudinary Cloud Name
  static const String uploadPreset =
      'inventory_images'; // Your unsigned upload preset

  static Future<String?> uploadImage(File imageFile) async {
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final data = jsonDecode(resStr);
      return data['secure_url']; // Return public URL
    } else {
      print('Upload failed: ${response.statusCode}');
      return null;
    }
  }
}
