import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:super_locker/services/encryption_service.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class KeyService {
  final EncryptionService encryptionService;
  KeyService(this.encryptionService);

  /// Generate a random VaultKey (32 bytes)
  Future<Uint8List> generateVaultKey() async {
    return await encryptionService.generateRandomBytes(32);
  }

  /// Encrypt the VaultKey with the MasterKey using AES-256-CBC
  Future<Map<String, String>> encryptVaultKey(
      Uint8List vaultKey, Uint8List masterKey) async {
    final iv = await encryptionService.generateRandomBytes(16);
    final encrypted = await _aesCbcEncrypt(vaultKey, masterKey, iv);
    return {
      'encryptedVaultKey': base64.encode(encrypted),
      'vaultKeyIV': base64.encode(iv),
    };
  }

  /// Decrypt the VaultKey with the MasterKey using AES-256-CBC
  Future<Uint8List> decryptVaultKey(String encryptedVaultKeyB64,
      String vaultKeyIVB64, Uint8List masterKey) async {
    final encrypted = base64.decode(encryptedVaultKeyB64);
    final iv = base64.decode(vaultKeyIVB64);
    return await _aesCbcDecrypt(encrypted, masterKey, iv);
  }

  /// AES-256-CBC encrypt raw bytes
  Future<Uint8List> _aesCbcEncrypt(
      Uint8List data, Uint8List key, Uint8List iv) async {
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: encrypt.IV(iv));
    return encrypted.bytes;
  }

  /// AES-256-CBC decrypt raw bytes
  Future<Uint8List> _aesCbcDecrypt(
      Uint8List encrypted, Uint8List key, Uint8List iv) async {
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(encrypt.Encrypted(encrypted),
        iv: encrypt.IV(iv));
    return Uint8List.fromList(decrypted);
  }

  /// Initialize vault key for user (first login)
  Future<void> initializeVaultKeyForUser(
      String userId, String masterPassword) async {
    print(
        '[DEBUG] KeyService: Starting vault key initialization for user: $userId');

    final salt = await encryptionService.generateRandomBytes(32);
    print('[DEBUG] KeyService: Salt generated');

    final masterKey =
        await encryptionService.deriveMasterKey(masterPassword, salt);
    print('[DEBUG] KeyService: Master key derived');

    final vaultKey = await generateVaultKey();
    print('[DEBUG] KeyService: Vault key generated');

    final encrypted = await encryptVaultKey(vaultKey, masterKey);
    print('[DEBUG] KeyService: Vault key encrypted');

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'salt': base64.encode(salt),
      'vaultKeyIV': encrypted['vaultKeyIV'],
      'encryptedVaultKey': encrypted['encryptedVaultKey'],
    }, SetOptions(merge: true));

    print('[DEBUG] KeyService: Vault key data stored in Firestore');
  }

  /// Unlock vault key for user (subsequent logins)
  Future<Uint8List?> unlockVaultKeyForUser(
      String userId, String masterPassword) async {
    print('[DEBUG] KeyService: Starting vault key unlock for user: $userId');

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!doc.exists) {
      print('[DEBUG] KeyService: No vault data found for user');
      return null;
    }

    final data = doc.data()!;
    print('[DEBUG] KeyService: Vault data retrieved from Firestore');

    final salt = base64.decode(data['salt']);
    final masterKey =
        await encryptionService.deriveMasterKey(masterPassword, salt);
    print('[DEBUG] KeyService: Master key derived from stored salt');

    final vaultKeyIV = data['vaultKeyIV'];
    final encryptedVaultKey = data['encryptedVaultKey'];
    final vaultKey =
        await decryptVaultKey(encryptedVaultKey, vaultKeyIV, masterKey);

    print('[DEBUG] KeyService: Vault key decrypted successfully');
    return vaultKey;
  }
}
