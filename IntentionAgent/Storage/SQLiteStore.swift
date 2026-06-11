import Foundation
import SQLite3

final class SQLiteStore {
    private var database: OpaquePointer?
    private let databaseURL: URL

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL
        try openDatabase()
        try createSchemaIfNeeded()
        Logger.log("SQLite", "Opened database at \(databaseURL.path)")
    }

    deinit {
        sqlite3_close(database)
    }

    func insertCaptureRecord(_ record: CaptureRecord) throws {
        let sql = "INSERT OR REPLACE INTO capture_records (id, timestamp, active_app_name, capture_policy, alignment, record_json) VALUES (?, ?, ?, ?, ?, ?);"
        let recordData = try JSONEncoder().encode(record)
        let recordJSONString = String(data: recordData, encoding: .utf8) ?? "{}"

        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        bindText(record.id.uuidString, at: 1, to: statement)
        sqlite3_bind_double(statement, 2, record.timestamp.timeIntervalSince1970)
        bindText(record.activeAppName, at: 3, to: statement)
        bindText(record.capturePolicy.rawValue, at: 4, to: statement)
        bindText(record.alignment.rawValue, at: 5, to: statement)
        bindText(recordJSONString, at: 6, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(prefix: "Failed to insert capture record")
        }
        Logger.log("SQLite", "Inserted capture record \(record.id.uuidString)")
    }

    func insertPayloadRecord(_ record: AIPayloadRecord) throws {
        let sql = "INSERT OR REPLACE INTO payload_records (id, timestamp, session_id, payload_path, record_json) VALUES (?, ?, ?, ?, ?);"
        let recordData = try JSONEncoder().encode(record)
        let recordJSONString = String(data: recordData, encoding: .utf8) ?? "{}"

        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        bindText(record.id.uuidString, at: 1, to: statement)
        sqlite3_bind_double(statement, 2, record.createdAt.timeIntervalSince1970)
        bindText(record.sessionID.uuidString, at: 3, to: statement)
        bindText(record.payloadPath, at: 4, to: statement)
        bindText(recordJSONString, at: 5, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(prefix: "Failed to insert payload record")
        }
        Logger.log("SQLite", "Inserted payload record \(record.id.uuidString)")
    }

    func fetchCaptureRecords(limit: Int = 200) throws -> [CaptureRecord] {
        let sql = "SELECT record_json FROM capture_records ORDER BY timestamp DESC LIMIT ?;"
        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var records: [CaptureRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeJSONColumn(CaptureRecord.self, statement: statement, columnIndex: 0) {
                records.append(record)
            }
        }
        return records
    }

    func fetchCaptureRecords(from startDate: Date, to endDate: Date) throws -> [CaptureRecord] {
        let sql = "SELECT record_json FROM capture_records WHERE timestamp >= ? AND timestamp <= ? ORDER BY timestamp ASC;"
        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, startDate.timeIntervalSince1970)
        sqlite3_bind_double(statement, 2, endDate.timeIntervalSince1970)

        var records: [CaptureRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeJSONColumn(CaptureRecord.self, statement: statement, columnIndex: 0) {
                records.append(record)
            }
        }
        return records
    }

    func fetchPayloadRecords(limit: Int = 50) throws -> [AIPayloadRecord] {
        let sql = "SELECT record_json FROM payload_records ORDER BY timestamp DESC LIMIT ?;"
        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var records: [AIPayloadRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = decodeJSONColumn(AIPayloadRecord.self, statement: statement, columnIndex: 0) {
                records.append(record)
            }
        }
        return records
    }

    func deleteAllRecords() throws {
        try execute(sql: "DELETE FROM capture_records;")
        try execute(sql: "DELETE FROM payload_records;")
        Logger.log("SQLite", "Deleted all capture and payload rows")
    }

    private func openDatabase() throws {
        if sqlite3_open(databaseURL.path, &database) != SQLITE_OK {
            throw databaseError(prefix: "Failed to open database")
        }
    }

    private func createSchemaIfNeeded() throws {
        try execute(sql: "CREATE TABLE IF NOT EXISTS capture_records (id TEXT PRIMARY KEY, timestamp REAL NOT NULL, active_app_name TEXT NOT NULL, capture_policy TEXT NOT NULL, alignment TEXT NOT NULL, record_json TEXT NOT NULL);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_capture_records_timestamp ON capture_records(timestamp DESC);")
        try execute(sql: "CREATE TABLE IF NOT EXISTS payload_records (id TEXT PRIMARY KEY, timestamp REAL NOT NULL, session_id TEXT NOT NULL, payload_path TEXT NOT NULL, record_json TEXT NOT NULL);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_payload_records_timestamp ON payload_records(timestamp DESC);")
    }

    private func execute(sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw databaseError(prefix: "SQLite execution failed")
        }
    }

    private func prepareStatement(sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw databaseError(prefix: "Failed to prepare statement")
        }
        return statement
    }

    private func bindText(_ text: String, at index: Int32, to statement: OpaquePointer?) {
        sqlite3_bind_text(statement, index, (text as NSString).utf8String, -1, SQLITE_TRANSIENT)
    }

    private func decodeJSONColumn<T: Decodable>(_ type: T.Type, statement: OpaquePointer?, columnIndex: Int32) -> T? {
        guard let cString = sqlite3_column_text(statement, columnIndex) else { return nil }
        let stringValue = String(cString: cString)
        guard let data = stringValue.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func databaseError(prefix: String) -> NSError {
        let message = sqlite3_errmsg(database).flatMap { String(cString: $0) } ?? "Unknown SQLite error"
        return NSError(domain: "SQLiteStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(prefix): \(message)"])
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
