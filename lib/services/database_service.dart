import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class DatabaseService {
  static Database? _database;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // StreamController to manage location updates
  final StreamController<List<Map<String, dynamic>>> _locationStreamController =
  StreamController.broadcast();

  Stream<List<Map<String, dynamic>>> get userLocationsStream =>
      _locationStreamController.stream;

  Future<String> _getOrCreateEncryptionKey() async {
    // Try to retrieve the key from secure storage
    String? key = await _secureStorage.read(key: 'encryptionKey');
    if (key == null) {
      // Generate a new random key if it doesn't exist
      final keyBytes = encrypt.Key.fromSecureRandom(32);
      key = keyBytes.base64;
      await _secureStorage.write(key: 'encryptionKey', value: key);
    }
    return key;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    var directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, 'secure_grid.db');
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  void _createDb(Database db, int newVersion) async {
    print('Creating UserLocations table');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS UserLocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      userId TEXT,
      latitude TEXT,
      longitude TEXT,
      timestamp TEXT,
      status TEXT,
      activity TEXT,
      roomId TEXT,
      isDirect INTEGER,
      groupOrFriendStatus TEXT,
      iv TEXT
    );
  ''');
    print('UserLocations table created');
  }

  String _encrypt(String text, encrypt.IV iv, String encryptionKey) {
    final key = encrypt.Key.fromBase64(encryptionKey);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(text, iv: iv);
    return encrypted.base64;
  }

  String _decrypt(String encryptedText, String ivString, String encryptionKey) {
    final key = encrypt.Key.fromBase64(encryptionKey);
    final iv = encrypt.IV.fromBase64(ivString);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
    return decrypted;
  }

  Future<void> insertUserLocation(Map<String, dynamic> location) async {
    final db = await database;
    final encryptionKey = await _getOrCreateEncryptionKey();

    // Generate a random IV
    final iv = encrypt.IV.fromLength(16);
    final ivString = iv.base64; // Store the IV as a Base64 string

    // Encrypt latitude and longitude only
    location['latitude'] = _encrypt(location['latitude'].toString(), iv, encryptionKey);
    location['longitude'] = _encrypt(location['longitude'].toString(), iv, encryptionKey);
    location['iv'] = ivString;

    print('Inserting user location into DB: $location');

    await db.insert('UserLocations', location, conflictAlgorithm: ConflictAlgorithm.replace);
    _emitLocationUpdates(); // Emit updates to the stream
  }

  Future<List<Map<String, dynamic>>> getUserLocationById(String userId) async {
    final db = await database;
    final encryptionKey = await _getOrCreateEncryptionKey();
    final results = await db.query(
      'UserLocations',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    // Decrypt data after fetching it from the database
    return results.map((location) {
      final ivString = location['iv'] as String;
      final encryptedLatitude = location['latitude'] as String;
      final encryptedLongitude = location['longitude'] as String;

      final decryptedLatitude = _decrypt(encryptedLatitude, ivString, encryptionKey);
      final decryptedLongitude = _decrypt(encryptedLongitude, ivString, encryptionKey);

      return {
        'userId': location['userId'],
        'latitude': double.parse(decryptedLatitude),
        'longitude': double.parse(decryptedLongitude),
        'timestamp': location['timestamp'],
        'status': location['status'],
        'activity': location['activity'],
        'roomId': location['roomId'],
        'isDirect': location['isDirect'],
        'groupOrFriendStatus': location['groupOrFriendStatus'],
      };
    }).toList();
  }

  Future<void> updateUserLocation(String userId, double latitude, double longitude, String timestamp) async {
    final db = await database;
    final encryptionKey = await _getOrCreateEncryptionKey();

    // Generate a random IV
    final iv = encrypt.IV.fromLength(16);
    final ivString = iv.base64; // Store the IV as a Base64 string

    // Encrypt latitude and longitude only
    final encryptedLatitude = _encrypt(latitude.toString(), iv, encryptionKey);
    final encryptedLongitude = _encrypt(longitude.toString(), iv, encryptionKey);

    print('Updating user location in DB: UserID: $userId, Latitude: $latitude, Longitude: $longitude, Timestamp: $timestamp');

    await db.update(
      'UserLocations',
      {
        'latitude': encryptedLatitude,
        'longitude': encryptedLongitude,
        'timestamp': timestamp,
        'iv': ivString, // Store the IV with the data
      },
      where: 'userId = ?',
      whereArgs: [userId],  // Use the plaintext userId for lookup
    );
  }

  void emitUpdatesToAppAfterUpdatingDB() {
    _emitLocationUpdates(); // Emit updates to the stream
  }

  Future<List<Map<String, dynamic>>> getUserLocations() async {
    final db = await database;
    final encryptionKey = await _getOrCreateEncryptionKey();
    final results = await db.query('UserLocations');

    // Decrypt data after fetching it from the database
    return results.map((location) {
      final ivString = location['iv'] as String;
      final encryptedLatitude = location['latitude'] as String;
      final encryptedLongitude = location['longitude'] as String;

      final decryptedLatitude = _decrypt(encryptedLatitude, ivString, encryptionKey);
      final decryptedLongitude = _decrypt(encryptedLongitude, ivString, encryptionKey);

      return {
        'userId': location['userId'],
        'latitude': double.parse(decryptedLatitude),
        'longitude': double.parse(decryptedLongitude),
        'timestamp': location['timestamp'],
        'status': location['status'],
        'activity': location['activity'],
        'roomId': location['roomId'],
        'isDirect': location['isDirect'],
        'groupOrFriendStatus': location['groupOrFriendStatus'],
      };
    }).toList();
  }

  Future<void> deleteUserLocation(int id) async {
    final db = await database;
    await db.delete('UserLocations', where: 'id = ?', whereArgs: [id]);
    _emitLocationUpdates(); // Emit updates to the stream
  }

  Future<void> updateLocationStatus(int id, String status) async {
    final db = await database;
    await db.update(
        'UserLocations',
        {'status': status},
        where: 'id = ?',
        whereArgs: [id]
    );
  }

  Future<void> clearAllData() async {
    var directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, 'secure_grid.db');

    // Close the database connection
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    // Delete the database file
    await deleteDatabase(path);

    // Reinitialize the database
    _database = await initDatabase();

    print("Database cleared and reinitialized with new schema.");
    _emitLocationUpdates(); // Emit updates to the stream
  }

  Future<void> verifyDatabase() async {
    final db = await database;

    // Check if the table exists
    var result = await db.rawQuery('PRAGMA table_info(UserLocations)');
    print('UserLocations table schema: $result');

    // Check if any data is in the table
    result = await db.query('UserLocations');
    print('Current data in UserLocations: $result');
  }

  void _emitLocationUpdates() async {
    final userLocations = await getUserLocations();
    _locationStreamController.add(userLocations);
  }

  void dispose() {
    _locationStreamController.close(); // Close the stream controller
  }
}