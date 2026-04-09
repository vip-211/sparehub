import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../utils/constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'spare_parts.db');
    final db = await openDatabase(
      path,
      version: 23,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureAdminAndStaff(db);
    await _enforceProductUniqueness(db);
    return db;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      try {
        await db.execute(
            'ALTER TABLE users ADD COLUMN status TEXT DEFAULT "ACTIVE"');
      } catch (e) {/* column may exist */}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN wholesalerPrice REAL DEFAULT 0.0');
      } catch (e) {/* column may exist */}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN retailerPrice REAL DEFAULT 0.0');
      } catch (e) {/* column may exist */}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN mechanicPrice REAL DEFAULT 0.0');
      } catch (e) {/* column may exist */}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN latitude REAL');
      } catch (e) {/* column may exist */}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN longitude REAL');
      } catch (e) {/* column may exist */}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN latitude REAL');
      } catch (e) {/* column may exist */}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN longitude REAL');
      } catch (e) {/* column may exist */}
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN deliveredBy TEXT');
      } catch (e) {/* column may exist */}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN deliveredAt TEXT');
      } catch (e) {/* column may exist */}
    }
    if (oldVersion < 6) {
      // Create notifications table
      await db.execute('''
        CREATE TABLE notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          message TEXT,
          targetRole TEXT,
          createdAt TEXT
        )
      ''');
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN imagePath TEXT');
      } catch (e) {/* column may exist */}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN shopImagePath TEXT');
      } catch (e) {/* column may exist */}
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE voice_corrections(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          recognized_text TEXT,
          corrected_text TEXT
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE product_aliases(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productId INTEGER,
          alias TEXT,
          pronunciation TEXT
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE order_requests(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerId INTEGER,
          customerName TEXT,
          text TEXT,
          photoPath TEXT,
          status TEXT,
          createdAt TEXT,
          assignedStaffId INTEGER,
          assignedStaffName TEXT
        )
      ''');
    }
    if (oldVersion < 12) {
      try {
        // Remove duplicate partNumbers keeping the smallest id
        await db.execute('''
          DELETE FROM products
          WHERE id NOT IN (
            SELECT MIN(id) FROM products GROUP BY partNumber
          )
          AND partNumber IN (
            SELECT partNumber FROM products GROUP BY partNumber HAVING COUNT(*) > 1
          )
        ''');
      } catch (_) {}
      try {
        await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_partNumber ON products(partNumber)');
      } catch (_) {}
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN rackNumber TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN enabled INTEGER DEFAULT 1');
      } catch (_) {}
    }
    if (oldVersion < 14) {
      try {
        await db
            .execute('ALTER TABLE users ADD COLUMN deleted INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN deleted INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db
            .execute('ALTER TABLE orders ADD COLUMN deleted INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN description TEXT');
      } catch (_) {}
    }
    if (oldVersion < 16) {
      try {
        await db.execute(
            'ALTER TABLE notifications ADD COLUMN isRead INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN imageUrl TEXT');
      } catch (_) {}
    }
    if (oldVersion < 17) {
      try {
        await db.execute(
            'ALTER TABLE users ADD COLUMN phone_verified INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 18) {
      try {
        await db
            .execute('ALTER TABLE users ADD COLUMN points INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN pointsRedeemed INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE orders ADD COLUMN pointsEarned INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 19) {
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN isFeatured INTEGER DEFAULT 0');
      } catch (_) {}
    }
    if (oldVersion < 20) {
      // Add category image and display order
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN imagePath TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE categories ADD COLUMN displayOrder INTEGER DEFAULT 0');
      } catch (_) {}

      // Add CMS settings table
      await db.execute('''
        CREATE TABLE cms_settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');

      // Seed default CMS values
      await db.insert('cms_settings',
          {'key': 'mechanic_home_title', 'value': 'Parts Mitra'});
      await db.insert('cms_settings', {
        'key': 'mechanic_banner_text',
        'value': 'मार्केटमध्ये दर वाढले,\nparts mitra ॲप वर नाही.'
      });
      await db.insert('cms_settings',
          {'key': 'mechanic_banner_btn', 'value': 'आता खरेदी करा'});
    }
    if (oldVersion < 21) {
      // Seed default layout order
      await db.insert('cms_settings', {
        'key': 'mechanic_home_layout',
        'value': 'header,search_bar,categories,banner,hot_deals'
      });
    }
    if (oldVersion < 22) {
      try {
        await db.execute(
            'ALTER TABLE categories ADD COLUMN iconCodePoint INTEGER');
      } catch (_) {}
    }
    if (oldVersion < 23) {
      try {
        await db.execute(
            'ALTER TABLE categories ADD COLUMN showOnHome INTEGER DEFAULT 1');
      } catch (_) {}
    }
  }

  Future<void> _enforceProductUniqueness(Database db) async {
    try {
      await db.execute('''
        DELETE FROM products
        WHERE id NOT IN (
          SELECT MIN(id) FROM products GROUP BY partNumber
        )
        AND partNumber IN (
          SELECT partNumber FROM products GROUP BY partNumber HAVING COUNT(*) > 1
        )
      ''');
    } catch (_) {}
    try {
      await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_partNumber ON products(partNumber)');
    } catch (_) {}
  }

  Future<void> _ensureAdminAndStaff(Database db) async {
    // Admin
    final List<Map<String, dynamic>> admins = await db
        .query('users', where: 'email = ?', whereArgs: ['admin@example.com']);
    if (admins.isEmpty) {
      await db.insert('users', {
        'email': 'admin@example.com',
        'password': 'password123',
        'name': 'System Admin',
        'phone': '9999999999',
        'address': 'Admin Office',
        'role': Constants.roleAdmin,
        'status': 'ACTIVE'
      });
    }

    // Staff
    final List<Map<String, dynamic>> staff = await db
        .query('users', where: 'email = ?', whereArgs: ['staff@example.com']);
    if (staff.isEmpty) {
      await db.insert('users', {
        'email': 'staff@example.com',
        'password': 'password123',
        'name': 'Delivery Staff',
        'phone': '8888888888',
        'address': 'Staff Hub',
        'role': Constants.roleStaff,
        'status': 'ACTIVE'
      });
    }

    // Super Manager
    final List<Map<String, dynamic>> superManagers = await db.query('users',
        where: 'email = ?', whereArgs: ['supermanager@example.com']);
    if (superManagers.isEmpty) {
      await db.insert('users', {
        'email': 'supermanager@example.com',
        'password': 'password123',
        'name': 'Super Manager',
        'phone': '7777777777',
        'address': 'HQ',
        'role': Constants.roleSuperManager,
        'status': 'ACTIVE'
      });
    }

    // Mechanic for SSO Demo
    final List<Map<String, dynamic>> mechanics = await db.query('users',
        where: 'email = ?', whereArgs: ['mechanic@example.com']);
    if (mechanics.isEmpty) {
      await db.insert('users', {
        'email': 'mechanic@example.com',
        'password': 'password123',
        'name': 'Demo Mechanic',
        'phone': '6666666666',
        'address': 'Mechanic Workshop',
        'role': Constants.roleMechanic,
        'status': 'ACTIVE'
      });
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE,
        password TEXT,
        name TEXT,
        phone TEXT,
        address TEXT,
        role TEXT,
        status TEXT DEFAULT "PENDING",
        latitude REAL,
        longitude REAL,
        phone_verified INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        partNumber TEXT,
        rackNumber TEXT,
        mrp REAL,
        sellingPrice REAL,
        wholesalerPrice REAL,
        retailerPrice REAL,
        mechanicPrice REAL,
        stock INTEGER,
        wholesalerId INTEGER,
        imagePath TEXT,
        description TEXT,
        enabled INTEGER DEFAULT 1,
        deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_products_partNumber ON products(partNumber)');

    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER,
        customerName TEXT,
        sellerId INTEGER,
        sellerName TEXT,
        totalAmount REAL,
        status TEXT,
        createdAt TEXT,
        latitude REAL,
        longitude REAL,
        deliveredBy TEXT,
        deliveredAt TEXT,
        deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER,
        productId INTEGER,
        productName TEXT,
        quantity INTEGER,
        price REAL,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        message TEXT,
        targetRole TEXT,
        imageUrl TEXT,
        isRead INTEGER DEFAULT 0,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE voice_corrections(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recognized_text TEXT,
        corrected_text TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE product_aliases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER,
        alias TEXT,
        pronunciation TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE order_requests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customerId INTEGER,
        customerName TEXT,
        text TEXT,
        photoPath TEXT,
        status TEXT,
        createdAt TEXT,
        assignedStaffId INTEGER,
        assignedStaffName TEXT
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    await db.insert('products', {
      'name': 'Brake Pad Set',
      'partNumber': 'BP-001',
      'mrp': 1200.0,
      'sellingPrice': 1000.0,
      'wholesalerPrice': 800.0,
      'retailerPrice': 900.0,
      'mechanicPrice': 950.0,
      'stock': 50,
      'wholesalerId': 1,
      'deleted': 0
    });

    await db.insert('products', {
      'name': 'Oil Filter',
      'partNumber': 'OF-002',
      'mrp': 450.0,
      'sellingPrice': 350.0,
      'wholesalerPrice': 250.0,
      'retailerPrice': 300.0,
      'mechanicPrice': 320.0,
      'stock': 0,
      'wholesalerId': 1,
      'deleted': 0
    });
  }
}
