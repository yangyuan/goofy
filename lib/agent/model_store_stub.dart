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

  double? get fraction => null;
}

class ModelStore {
  const ModelStore();

  Future<ModelFileStatus> checkDefaultModel() async {
    return const ModelFileStatus(
      path: '',
      fileName: defaultE2bModelFileName,
      downloadUrl: defaultE2bModelUrl,
      exists: false,
      bytes: 0,
    );
  }

  Future<ModelFileStatus> downloadDefaultModel({
    void Function(ModelDownloadProgress progress)? onProgress,
  }) {
    throw UnsupportedError(
      'Model download is only available on native builds.',
    );
  }
}
