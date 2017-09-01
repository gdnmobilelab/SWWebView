//
//  Migrate.swift
//  ServiceWorkerContainer
//
//  Created by alastair.coote on 13/06/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

fileprivate struct MigrationAndVersion {
    let fileName: URL
    let version: Int
}

public class DatabaseMigration {

    fileprivate static func ensureMigrationTableCreated(_ db: SQLiteConnection) throws {

        try db.exec(sql: """
            CREATE TABLE IF NOT EXISTS _migrations (
                 "identifier" text NOT NULL,
                 "value" integer NOT NULL,
                PRIMARY KEY("identifier")
            );

            INSERT OR IGNORE INTO _migrations (identifier, value) VALUES ('currentVersion', 0);
        """)
    }

    fileprivate static func getCurrentMigrationVersion(_ db: SQLiteConnection) throws -> Int {

        return try db.select(sql: "SELECT value FROM _migrations WHERE identifier = 'currentVersion'") { rs -> Int in
            if try rs.next() == false {
                throw ErrorMessage("Could not find row for current migration version")
            }
            guard let currentVersion = try rs.int("value") else {
                throw ErrorMessage("Could not find row for current migration version")
            }
            return currentVersion
        }
    }

    public static func check(dbPath: URL, migrationsPath: URL) throws -> Int {

        return try SQLiteConnection.inConnection(dbPath) { connection in

            try connection.inTransaction {

                try self.ensureMigrationTableCreated(connection)
                let currentVersion = try self.getCurrentMigrationVersion(connection)

                // Grab all the migration files currently in our bundle.
                let migrationFilePaths = try FileManager.default.contentsOfDirectory(at: migrationsPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsSubdirectoryDescendants)

                let migrationFiles = try migrationFilePaths
                    .filter { $0.pathExtension == "sql" }
                    .map { url -> MigrationAndVersion in

                        // Extract the version number (the number before the _ in the file)
                        guard let idx = Int(url.deletingPathExtension().lastPathComponent.components(separatedBy: "_")[0]) else {
                            throw ErrorMessage("Could not extract version number from: \(url.absoluteString)")
                        }

                        return MigrationAndVersion(fileName: url, version: idx)
                    }
                    // Remove any migrations we've already completed
                    .filter { $0.version > currentVersion }
                    // Sort them by version, so they execute in order
                    .sorted(by: { $1.version > $0.version })

                for migration in migrationFiles {

                    Log.info?("Processing migration file: " + migration.fileName.lastPathComponent)
                    let sql = try String(contentsOfFile: migration.fileName.path)

                    do {
                        try connection.exec(sql: sql)
                    } catch {
                        throw ErrorMessage("Error when attempting migration: " + migration.fileName.absoluteString + ", internal error: " + String(describing: error))
                    }
                }

                guard let lastMigration = migrationFiles.last else {
                    Log.debug?("No pending migration files found")
                    return currentVersion
                }

                try connection.update(sql: "UPDATE _migrations SET value = ? WHERE identifier = 'currentVersion'", values: [lastMigration.version])
                return lastMigration.version
            }
        }
    }
}
