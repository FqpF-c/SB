import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  // Write string value
  static Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // Read string value
  static Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  // Delete single key
  static Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // Delete all keys
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // ✅ Typed support (optional)
  static Future<void> writeBool(String key, bool value) =>
      write(key, value.toString());

  static Future<bool> readBool(String key) async {
    final val = await read(key);
    return val == 'true';
  }

  static Future<void> writeInt(String key, int value) =>
      write(key, value.toString());

  static Future<int?> readInt(String key) async {
    final val = await read(key);
    return val != null ? int.tryParse(val) : null;
  }

  // 🔄 Migration from SharedPreferences
  static Future<void> migrateFromSharedPreferences(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    for (String key in keys) {
      if (prefs.containsKey(key)) {
        final value = prefs.get(key);
        if (value is String) {
          await write(key, value);
        } else if (value is bool) {
          await writeBool(key, value);
        } else if (value is int) {
          await writeInt(key, value);
        } else if (value is double) {
          await write(key, value.toString());
        }
        await prefs.remove(key);
        print('✅ Migrated key "$key" from SharedPreferences to SecureStorage');
      }
    }
  }
}
