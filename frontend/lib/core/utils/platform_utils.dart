import 'platform_utils_stub.dart'
    if (dart.library.html) 'platform_utils_web.dart' as platform;

class PlatformUtils {
  static void downloadFile(String content, String fileName) {
    platform.downloadFile(content, fileName);
  }
}
