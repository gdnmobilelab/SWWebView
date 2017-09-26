import Foundation
import ServiceWorker
import PromiseKit

/// Still trying to figure out the best trade-off between memory and performance for keeping
/// DB connections hanging around. But this pool ensures that we only ever have one connection
/// open for a URL at a time, and automatically closes them when we're done. In the future, we
/// can customise behaviour here depending on whether we're in the Notification Extension or
/// the full app, maybe.
class DBConnectionPool {

    fileprivate static var currentOpenConnections = NSHashTable<SQLiteConnection>.weakObjects()

    // Rather than do a migration check for every opened connection (expensive!) we keep track of which
    // ones we've already checked in this session. If we were opening a lot of connections this would
    // be a problem, but we don't (yet, anyway) so this will do for now.
    fileprivate static var checkedMigrations = Set<String>()

    static func inConnection<T>(at url: URL, type: DatabaseType, _ callback: (SQLiteConnection) throws -> Promise<T>) -> Promise<T> {

        return firstly {
            let connection = try DBConnectionPool.getConnection(for: url, type: type)
            return try callback(connection)
        }
    }

    static func inConnection<T>(at url: URL, type: DatabaseType, _ callback: (SQLiteConnection) throws -> T) throws -> T {

        let connection = try DBConnectionPool.getConnection(for: url, type: type)
        return try callback(connection)
    }

    fileprivate static func getConnection(for url: URL, type: DatabaseType) throws -> SQLiteConnection {

        let existing = currentOpenConnections.allObjects.first(where: { $0.url.absoluteString == url.absoluteString })

        if let doesExist = existing {
            return doesExist
        }

        if self.checkedMigrations.contains(url.absoluteString) == false {
            // Need to perform migration checks, but exactly what we run depends on what DB type
            // we are creating. Potential problem here with running different DB types at the same
            // URL.
            try self.checkMigrationsFor(dbPath: url, type: type)
            self.checkedMigrations.insert(url.absoluteString)
        }

        let newConnection = try SQLiteConnection(url)
        self.currentOpenConnections.add(newConnection)
        return newConnection
    }

    fileprivate static func checkMigrationsFor(dbPath: URL, type: DatabaseType) throws {
        Log.info?("Migration check for \(dbPath.path) not done yet, doing it now...")

        let migrations = URL(fileURLWithPath: Bundle(for: DBConnectionPool.self).bundlePath, isDirectory: true)
            .appendingPathComponent("DatabaseMigrations", isDirectory: true)
            .appendingPathComponent(type.rawValue, isDirectory: true)

        // This might be the first time it's being run, in which case, we need to ensure we have the
        // directory structure ready.
        try FileManager.default.createDirectory(at: dbPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

        _ = try DatabaseMigration.check(dbPath: dbPath, migrationsPath: migrations)
    }
}
