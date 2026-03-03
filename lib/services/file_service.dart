import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// ─── FileService ──────────────────────────────────────────────────────────────
///
/// Static utility class for all local filesystem operations related to clients.
///
/// Folder structure on disk:
///   <ApplicationDocuments>/
///     ClientManagerV2/
///       Clients/
///         <ClientName>/          ← one folder per client
///           Ταυτότητα_1709123456789.jpg
///           Σύμβαση_1709124000000.pdf
///           ...
///
/// All methods are async because filesystem I/O should never block the UI thread.
class FileService {
  // ── Folder Management ──────────────────────────────────────────────────────

  /// Returns the absolute path to the client's document folder,
  /// creating it (and all parent directories) if it doesn't exist yet.
  ///
  /// [clientName] is sanitised to strip characters that are illegal in
  /// directory names on Windows ( \ / : * ? " < > | ).
  ///
  /// DEBUG TIP: If the folder cannot be found, call this method and print
  /// the returned path to confirm where the app is storing files.
  static Future<String> getClientFolder(String clientName) async {
    final docs = await getApplicationDocumentsDirectory();

    // Strip filesystem-illegal characters from the name
    final safeName = clientName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final baseDir =
        Directory(p.join(docs.path, 'ClientManagerV2', 'Clients', safeName));

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true); // creates all missing parents
    }
    return baseDir.path;
  }

  // ── Explorer / File Manager Integration ───────────────────────────────────

  /// Opens the client's document folder in the native file manager:
  ///   • Windows  → explorer.exe <path>
  ///   • macOS    → open <path>
  ///   • Linux    → xdg-open <path>
  ///
  /// The folder is automatically created if it doesn't exist yet.
  ///
  /// DEBUG TIP: If the explorer window doesn't open, verify that Process.run
  /// exits cleanly by checking its exit code.
  static Future<void> openClientFolderInExplorer(String clientName) async {
    final folderPath = await getClientFolder(clientName);

    if (Platform.isWindows) {
      await Process.run('explorer', [folderPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [folderPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [folderPath]);
    }
  }

  // ── File Import ────────────────────────────────────────────────────────────

  /// Copies [sourceFile] into the client's folder with an auto-generated name:
  ///   <docType>_<millisecondsSinceEpoch><originalExtension>
  ///
  /// Example: 'Ταυτότητα_1709123456789.jpg'
  ///
  /// The original file is NOT deleted (this is a copy, not a move).
  /// Returns the full path of the newly created copy.
  ///
  /// Parameters:
  ///   [clientName] – Used to locate/create the target folder.
  ///   [sourceFile] – The file selected by the user via FilePicker.
  ///   [docType]    – Human-readable label chosen in the import dialog
  ///                  (e.g. 'Ταυτότητα', 'Σύμβαση Εργασίας').
  static Future<String> importFile({
    required String clientName,
    required File sourceFile,
    required String docType,
  }) async {
    final destination = await getClientFolder(clientName);
    final ext = p.extension(sourceFile.path); // e.g. '.pdf', '.jpg'
    final ts = DateTime.now().millisecondsSinceEpoch;

    // Sanitise docType for use as a filename component
    final safeDocType = docType.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    final newPath = p.join(destination, '${safeDocType}_$ts$ext');
    await sourceFile.copy(newPath);
    return newPath;
  }

  // ── File Listing ───────────────────────────────────────────────────────────

  /// Returns a list of all [File]s inside the client's document folder.
  /// Returns an empty list if the folder doesn't exist yet.
  ///
  /// Only direct children (no subdirectories) are returned.
  /// Subdirectory entries are automatically filtered out by [whereType<File>].
  static Future<List<File>> listClientFiles(String clientName) async {
    final folderPath = await getClientFolder(clientName);
    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];
    final entities = await dir.list().toList();
    return entities.whereType<File>().toList();
  }

  // ── Scanner Workflow (legacy) ──────────────────────────────────────────────

  /// Moves all files from a scanner output directory into the client folder.
  /// Renames each file with a 'Scan_<timestamp>_' prefix to avoid collisions.
  ///
  /// Returns the number of files successfully moved.
  ///
  /// NOTE: This assumes the scanner software saves files to a known [scannerPath].
  ///       Direct WIA scanner integration is planned for a future sprint.
  static Future<int> moveFromScanner(
      String clientName, String scannerPath) async {
    final destination = await getClientFolder(clientName);
    final scannerDir = Directory(scannerPath);

    if (!await scannerDir.exists()) return 0;

    int movedCount = 0;
    await for (var entity in scannerDir.list()) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        final newPath = p.join(destination,
            'Scan_${DateTime.now().millisecondsSinceEpoch}_$fileName');
        await entity.copy(newPath);
        await entity.delete(); // remove original after successful copy
        movedCount++;
      }
    }
    return movedCount;
  }
}
