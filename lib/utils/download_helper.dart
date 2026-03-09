import 'dart:convert';
import 'dart:html' as html;

/// Helper class for downloading JSON data as files in Flutter Web
class DownloadHelper {
  /// Download a JSON object as a file
  ///
  /// [filename] - The name of the file to download
  /// [data] - The JSON data to download (Map<String, dynamic>)
  static void downloadJson(String filename, Map<String, dynamic> data) {
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonString);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    // ignore: unused_local_variable
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
