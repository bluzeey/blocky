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

    func insertFocusTask(_ task: FocusTask) throws {
        let sql = "INSERT OR REPLACE INTO focus_tasks (id, title, duration_minutes, list_type, completed_at, created_at, record_json) VALUES (?, ?, ?, ?, ?, ?, ?);"
        let recordData = try JSONEncoder().encode(task)
        let recordJSONString = String(data: recordData, encoding: .utf8) ?? "{}"

        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        bindText(task.id.uuidString, at: 1, to: statement)
        bindText(task.title, at: 2, to: statement)
        sqlite3_bind_int(statement, 3, Int32(task.durationMinutes))
        bindText(task.listType.rawValue, at: 4, to: statement)
        if let completedAt = task.completedAt {
            sqlite3_bind_double(statement, 5, completedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 5)
        }
        sqlite3_bind_double(statement, 6, task.createdAt.timeIntervalSince1970)
        bindText(recordJSONString, at: 7, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(prefix: "Failed to insert focus task")
        }
        Logger.log("SQLite", "Inserted focus task \(task.id.uuidString)")
    }

    func fetchFocusTasks(listType: TaskListType? = nil) throws -> [FocusTask] {
        var sql = "SELECT record_json FROM focus_tasks"
        if let listType {
            sql += " WHERE list_type = '\(listType.rawValue)'"
        }
        sql += " ORDER BY created_at ASC;"

        let statement = try prepareStatement(sql: sql)
        defer { sqlite3_finalize(statement) }

        var tasks: [FocusTask] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let task = decodeJSONColumn(FocusTask.self, statement: statement, columnIndex: 0) {
                tasks.append(task)
            }
        }
        return tasks
    }

    func updateFocusTaskCompleted(id: UUID, completedAt: Date?) throws {
        let fetchSQL = "SELECT record_json FROM focus_tasks WHERE id = ?;"
        let fetchStmt = try prepareStatement(sql: fetchSQL)
        defer { sqlite3_finalize(fetchStmt) }
        bindText(id.uuidString, at: 1, to: fetchStmt)

        guard sqlite3_step(fetchStmt) == SQLITE_ROW,
              var task = decodeJSONColumn(FocusTask.self, statement: fetchStmt, columnIndex: 0) else {
            throw databaseError(prefix: "Failed to fetch focus task for completion update")
        }

        task.completedAt = completedAt
        let updatedData = try JSONEncoder().encode(task)
        let updatedJSON = String(data: updatedData, encoding: .utf8) ?? "{}"

        let updateSQL = "UPDATE focus_tasks SET completed_at = ?, record_json = ? WHERE id = ?;"
        let updateStmt = try prepareStatement(sql: updateSQL)
        defer { sqlite3_finalize(updateStmt) }

        if let completedAt {
            sqlite3_bind_double(updateStmt, 1, completedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(updateStmt, 1)
        }
        bindText(updatedJSON, at: 2, to: updateStmt)
        bindText(id.uuidString, at: 3, to: updateStmt)

        guard sqlite3_step(updateStmt) == SQLITE_DONE else {
            throw databaseError(prefix: "Failed to update focus task completion")
        }

        Logger.log("SQLite", "Updated focus task completion id=\(id.uuidString) completed=\(completedAt != nil)")
    }

    func deleteCompletedFocusTasks() throws {
        try execute(sql: "DELETE FROM focus_tasks WHERE completed_at IS NOT NULL;")
        Logger.log("SQLite", "Deleted completed focus tasks")
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
        try execute(sql: "CREATE TABLE IF NOT EXISTS focus_tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, duration_minutes INTEGER NOT NULL, list_type TEXT NOT NULL, completed_at REAL, created_at REAL NOT NULL, record_json TEXT NOT NULL);")
        try execute(sql: "CREATE INDEX IF NOT EXISTS idx_focus_tasks_list_type ON focus_tasks(list_type);")
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
