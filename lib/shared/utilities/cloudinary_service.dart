import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:file_picker/file_picker.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // TODO: Replace with your Cloudinary credentials
  static const String _cloudName = 'dv5ykewmd';
  static const String _uploadPreset =
      'firestore_storage'; // or create a custom preset

  late final CloudinaryPublic _cloudinary;

  void initialize() {
    _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  /// Upload profile picture to Cloudinary
  /// Returns the secure URL of the uploaded image
  Future<String> uploadProfilePicture(File imageFile, String userId) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: 'profile_pictures',
          resourceType: CloudinaryResourceType.Image,
          publicId: userId, // Use userId as filename - will overwrite old image
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print('[Cloudinary] Upload error: $e');
      rethrow;
    }
  }

  /// Upload task submission file to Cloudinary
  /// Returns the secure URL and public ID of the uploaded file
  Future<Map<String, String>> uploadSubmissionFile({
    required PlatformFile file,
    required String taskId,
    required String submissionId,
  }) async {
    try {
      if (file.bytes == null) {
        throw Exception('File bytes are null');
      }

      // Determine resource type based on file extension
      CloudinaryResourceType resourceType = CloudinaryResourceType.Auto;
      if (file.extension != null) {
        final ext = file.extension!.toLowerCase();
        if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
          resourceType = CloudinaryResourceType.Image;
        } else if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv'].contains(ext)) {
          resourceType = CloudinaryResourceType.Video;
        }
      }

      // Create a unique public ID for the file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = '$taskId/$submissionId/${timestamp}_${file.name}';

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          file.bytes!,
          identifier: file.name,
          folder: 'task_submissions',
          resourceType: resourceType,
          publicId: publicId,
        ),
      );

      return {'url': response.secureUrl, 'publicId': response.publicId};
    } catch (e) {
      print('[Cloudinary] Upload error: $e');
      rethrow;
    }
  }

  /// Note: Cloudinary free tier doesn't support deletion via API
  /// Old images are automatically overwritten when uploading with same publicId
  Future<void> deleteProfilePicture(String userId) async {
    // Deletion not supported in cloudinary_public package
    // Images are overwritten on new upload, so this is not critical
    print(
      '[Cloudinary] Delete not supported - image will be overwritten on next upload',
    );
  }
}
