import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

const defaultE2bModelFileName = 'gemma-4-E2B-it.litertlm';
const defaultE2bModelUrl = String.fromEnvironment(
  'GOOFY_E2B_MODEL_URL',
  defaultValue:
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
);

class ModelFileStatus {
  const ModelFileStatus({
    required this.path,
    required this.fileName,
    required this.downloadUrl,
    required this.exists,
    required this.bytes,
  });

  final String path;
  final String fileName;
  final String downloadUrl;
  final bool exists;
  final int bytes;
}

class ModelDownloadProgress {
  const ModelDownloadProgress({required this.receivedBytes, this.totalBytes});

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return receivedBytes / total;
  }
}

class ModelStore {
  const ModelStore();

  Future<ModelFileStatus> checkDefaultModel() async {
    final file = await _defaultModelFile();
    final exists = await file.exists();
    final bytes = exists ? await file.length() : 0;
    _log('Model check path=${file.path} exists=$exists bytes=$bytes');

    return ModelFileStatus(
      path: file.path,
      fileName: defaultE2bModelFileName,
      downloadUrl: defaultE2bModelUrl,
      exists: exists && bytes > 0,
      bytes: bytes,
    );
  }

  Future<ModelFileStatus> downloadDefaultModel({
    void Function(ModelDownloadProgress progress)? onProgress,
  }) async {
    final file = await _defaultModelFile();
    final tempFile = File('${file.path}.download');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);

    IOSink? sink;
    try {
      _log('Starting model download url=$defaultE2bModelUrl');
      final request = await client.getUrl(Uri.parse(defaultE2bModelUrl));
      final response = await request.close();
      _log(
        'Model download response status=${response.statusCode} reason=${response.reasonPhrase} contentLength=${response.contentLength} redirects=${response.redirects.map((redirect) => '${redirect.statusCode}:${redirect.location}').join(',')}',
      );
      if (response.statusCode < HttpStatus.ok ||
          response.statusCode >= HttpStatus.multipleChoices) {
        final bodyPreview = await _readBodyPreview(response);
        _log('Model download failed bodyPreview=$bodyPreview');
        throw HttpException(
          _downloadErrorMessage(response.statusCode, bodyPreview),
          uri: response.redirects.isNotEmpty
              ? response.redirects.last.location
              : Uri.parse(defaultE2bModelUrl),
        );
      }

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      sink = tempFile.openWrite();
      var receivedBytes = 0;
      var nextLogBytes = 256 * 1024 * 1024;
      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : null;

      await for (final chunk in response) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        if (receivedBytes >= nextLogBytes) {
          _log(
            'Model download progress received=$receivedBytes total=$totalBytes',
          );
          nextLogBytes += 256 * 1024 * 1024;
        }
        onProgress?.call(
          ModelDownloadProgress(
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ),
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
      _log('Model download complete path=${file.path} bytes=$receivedBytes');
      return checkDefaultModel();
    } catch (error, stackTrace) {
      _log('Model download error', error, stackTrace);
      await sink?.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
        _log('Deleted partial model download path=${tempFile.path}');
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> _defaultModelFile() async {
    final appSupport = _applicationSupportDirectory();
    final modelDirectory = Directory('${appSupport.path}/models');
    if (!await modelDirectory.exists()) {
      await modelDirectory.create(recursive: true);
    }
    return File('${modelDirectory.path}/$defaultE2bModelFileName');
  }

  Future<String> _readBodyPreview(HttpClientResponse response) async {
    final buffer = StringBuffer();
    await for (final chunk in response.transform(utf8.decoder)) {
      buffer.write(chunk);
      if (buffer.length >= 1000) break;
    }
    final preview = buffer.toString().trim();
    if (preview.length <= 1000) return preview;
    return preview.substring(0, 1000);
  }

  String _downloadErrorMessage(int statusCode, String bodyPreview) {
    final detail = bodyPreview.isEmpty ? '' : '\n\n$bodyPreview';
    if (statusCode == HttpStatus.unauthorized) {
      return 'Download failed with HTTP 401. Hugging Face rejected the default Gemma E2B URL. The model may be gated, private, or the URL may need to be replaced with --dart-define=GOOFY_E2B_MODEL_URL=<direct-download-url>.$detail';
    }
    return 'Download failed with HTTP $statusCode.$detail';
  }

  void _log(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'goofy.model_store',
      error: error,
      stackTrace: stackTrace,
    );
    stderr.writeln('[goofy.model_store] $message');
    if (error != null) {
      stderr.writeln('[goofy.model_store] error=$error');
    }
  }

  Directory _applicationSupportDirectory() {
    const override = String.fromEnvironment('GOOFY_APP_SUPPORT_DIR');
    if (override.isNotEmpty) {
      return Directory(override);
    }

    final home = Platform.environment['HOME'];
    if ((Platform.isMacOS || Platform.isIOS) && home != null) {
      return Directory('$home/Library/Application Support/goofy');
    }

    if (Platform.isLinux && home != null) {
      final dataHome = Platform.environment['XDG_DATA_HOME'];
      return Directory(
        dataHome == null || dataHome.isEmpty
            ? '$home/.local/share/goofy'
            : '$dataHome/goofy',
      );
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return Directory('$appData\\goofy');
      }
    }

    return Directory('${Directory.systemTemp.path}/goofy');
  }
}
