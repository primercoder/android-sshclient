import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;
import 'package:path/path.dart' as p;

class GeneratedKeys {
  final String privateKeyContent;
  final String publicKeyContent;
  final String privateKeyPath;
  final String publicKeyPath;

  const GeneratedKeys({
    required this.privateKeyContent,
    required this.publicKeyContent,
    required this.privateKeyPath,
    required this.publicKeyPath,
  });
}

class KeyService {
  static Future<GeneratedKeys> generateKeyPair({
    required String hostId,
    required String comment,
    required String keysDir,
  }) async {
    final dir = Directory(keysDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final seed = ed25519.SigningKey.generate();
    final publicKeyBytes = seed.verifyKey.asTypedList;
    final privateKeyBytes = seed.asTypedList;

    final keyPair = OpenSSHEd25519KeyPair(publicKeyBytes, privateKeyBytes, comment);
    final privatePem = keyPair.toPem();

    final pubEncoded = keyPair.toPublicKey().encode();
    final pubLine = 'ssh-ed25519 ${base64Encode(pubEncoded)} $comment';

    final shortId = hostId.replaceAll('-', '').substring(0, 8);
    final privPath = p.join(keysDir, 'k_$shortId.priv');
    final pubPath = p.join(keysDir, 'k_$shortId.pub');

    await File(privPath).writeAsString(privatePem);
    await File(pubPath).writeAsString(pubLine);

    return GeneratedKeys(
      privateKeyContent: privatePem,
      publicKeyContent: pubLine,
      privateKeyPath: privPath,
      publicKeyPath: pubPath,
    );
  }

  static Future<String?> readKeyFile(String path) async {
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null;
    }
  }

  static bool isValidPrivateKey(String content) {
    try {
      SSHKeyPair.fromPem(content);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String? extractPublicKeyLine(String privateKeyPem, String comment) {
    try {
      final pairs = SSHKeyPair.fromPem(privateKeyPem);
      if (pairs.isEmpty) return null;
      final pubEncoded = pairs.first.toPublicKey().encode();
      return '${pairs.first.type} ${base64Encode(pubEncoded)} $comment';
    } catch (_) {
      return null;
    }
  }

  static Future<String> getPublicKeyContent(String publicKeyPath) async {
    try {
      return await File(publicKeyPath).readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<bool> exportPublicKey(String sourcePath, String targetPath) async {
    try {
      final content = await File(sourcePath).readAsString();
      await File(targetPath).writeAsString(content);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Copy a key file into the app's internal keys directory.
  /// Returns the destination path, or null on failure.
  static Future<String?> importKeyFile(String sourcePath, String keysDir, String fileName) async {
    try {
      final dir = Directory(keysDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final dest = p.join(keysDir, fileName);
      await File(sourcePath).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  static String shortName(String hostId) {
    return 'k_${hostId.replaceAll('-', '').substring(0, 8)}';
  }
}
