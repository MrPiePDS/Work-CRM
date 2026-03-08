import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class VersionService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/MrPiePDS/Work-CRM/releases/latest';

  /// Compares local version with GitHub release tag. Returns true if an update is available.
  Future<bool> checkForUpdates() async {
    try {
      final dio = Dio();
      final response = await dio.get(_githubApiUrl);

      if (response.statusCode == 200) {
        final latestTag = response.data['tag_name'] as String;
        final latestVersion = latestTag.replaceAll('v', '');

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        return _isVersionGreater(latestVersion, currentVersion);
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return false;
  }

  /// Initiates the download and install process based on the platform.
  Future<bool> downloadAndInstallUpdate(
      Function(int progress, int total) onProgress) async {
    try {
      final dio = Dio();
      final response = await dio.get(_githubApiUrl);

      if (response.statusCode != 200) return false;

      final releaseData = response.data;
      final assets = releaseData['assets'] as List;

      if (Platform.isAndroid) {
        final apkAsset = _findAssetByExtension(assets, '.apk');
        if (apkAsset != null) {
          final downloadUrl = apkAsset['browser_download_url'] as String;
          OtaUpdate()
              .execute(downloadUrl, destinationFilename: 'app-update.apk')
              .listen(
            (OtaEvent event) {
              if (event.status == OtaStatus.DOWNLOADING) {
                int progress = int.tryParse(event.value ?? '0') ?? 0;
                onProgress(progress, 100);
              } else if (event.status == OtaStatus.INSTALLING) {
                onProgress(100, 100);
              }
            },
            onError: (err) => debugPrint('OTA Update failed: $err'),
          );
          return true;
        }
      } else if (Platform.isWindows) {
        final exeAsset = _findAssetByExtension(assets, '.exe');
        if (exeAsset != null) {
          final downloadUrl = exeAsset['browser_download_url'] as String;
          final tempDir = await getTemporaryDirectory();
          final savePath = '${tempDir.path}\\ClientManager_Update.exe';

          await dio.download(
            downloadUrl,
            savePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                onProgress(received, total);
              }
            },
          );

          onProgress(100, 100);

          // Run the downloaded installer detached
          await Process.start(
            savePath,
            ['/SILENT', '/SUPPRESSMSGBOXES'], // Silent install
            mode: ProcessStartMode.detached,
          );

          // Exit the app so it can be overwritten without "File in Use" errors
          exit(0);
        }
      } else {
        // macOS, Linux, iOS fallback: open the GitHub release URL
        final htmlUrl = releaseData['html_url'] as String;
        final uri = Uri.parse(htmlUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error downloading/installing update: $e');
    }
    return false;
  }

  Map<String, dynamic>? _findAssetByExtension(List assets, String extension) {
    for (var asset in assets) {
      final name = asset['name'] as String;
      if (name.toLowerCase().endsWith(extension)) {
        return asset as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Helper to compare two semantic version strings
  bool _isVersionGreater(String latest, String current) {
    List<int> latestParts =
        latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int l = latestParts.length > i ? latestParts[i] : 0;
      int c = currentParts.length > i ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false; // Equal or older
  }
}
