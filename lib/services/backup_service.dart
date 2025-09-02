import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

class BackupService {
  static Future<File> exportBackup() async {
    final dir = await getApplicationDocumentsDirectory();
    final archive = Archive();

    for (final name in Hive.boxNames) {
      final f = File('${dir.path}/$name.hive');
      if (await f.exists()) {
        final bytes = await f.readAsBytes();
        archive.addFile(ArchiveFile('$name.hive', bytes.length, bytes));
      }
    }

    final data = ZipEncoder().encode(archive)!;
    final out = File('${dir.path}/fitapp-backup.zip');
    await out.writeAsBytes(data, flush: true);
    return out;
  }

  static Future<void> restoreBackup(File zipFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Feche boxes antes de sobrescrever
    await Hive.close();

    for (final file in archive) {
      final out = File('${dir.path}/${file.name}');
      await out.writeAsBytes(file.content as List<int>, flush: true);
    }
    // Após restore, reabra boxes reiniciando o app/manual
  }
}
