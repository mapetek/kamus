import Foundation
import SQLite3

// Swift, SQLITE_TRANSIENT makrosunu import edemez; bind edilen string'in
// kopyalanması için bu sabit zorunlu (yoksa dangling pointer oluşur).
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Aranan her kelimenin ham TDK yanıtını yerel SQLite veritabanında saklar.
/// Tüm metotlar hatasızdır: veritabanı sorunları aramayı asla bozmaz, sadece loglanır.
actor DictionaryStore {
    static let shared = DictionaryStore()

    private var db: OpaquePointer?
    private var didAttemptOpen = false
    private let locale = Locale(identifier: "tr_TR")

    /// Başarılı bir aramayı kaydeder; kelime zaten varsa yanıtı günceller ve sayacı artırır.
    func save(word: String, responseJSON: Data) {
        guard openIfNeeded() else { return }
        guard let json = String(data: responseJSON, encoding: .utf8), !json.isEmpty else { return }
        let sql = """
            INSERT INTO words (word, response_json, first_searched_at, last_searched_at, search_count)
            VALUES (?1, ?2, ?3, ?3, 1)
            ON CONFLICT(word) DO UPDATE SET
                response_json    = excluded.response_json,
                last_searched_at = excluded.last_searched_at,
                search_count     = search_count + 1;
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logError("save prepare")
            return
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, canonical(word), -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, json, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        if sqlite3_step(stmt) != SQLITE_DONE {
            logError("save step")
        }
    }

    /// Kelime için kayıtlı ham JSON yanıtını döndürür; yoksa nil.
    func cachedResponse(for word: String) -> Data? {
        guard openIfNeeded() else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT response_json FROM words WHERE word = ?1 LIMIT 1;",
                                 -1, &stmt, nil) == SQLITE_OK else {
            logError("cachedResponse prepare")
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, canonical(word), -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cString).data(using: .utf8)
    }

    /// Çevrimdışıyken önbellekten servis edilen bir arama için sayaç ve zaman damgasını günceller.
    func touch(word: String) {
        guard openIfNeeded() else { return }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, """
            UPDATE words SET last_searched_at = ?1, search_count = search_count + 1 WHERE word = ?2;
            """, -1, &stmt, nil) == SQLITE_OK else {
            logError("touch prepare")
            return
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, canonical(word), -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) != SQLITE_DONE {
            logError("touch step")
        }
    }

    // MARK: - Private

    private func canonical(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: locale)
    }

    /// Uygulama "TDKDictionary" adıyla dağıtıldığı dönemde biriken sözlük veritabanını
    /// yeni klasöre taşır. Yeni klasör zaten varsa dokunulmaz — üzerine yazmak
    /// kullanıcının biriktirdiği kelimeleri silerdi.
    private func migrateLegacyDirectory(from legacy: URL, to destination: URL) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacy.path), !fm.fileExists(atPath: destination.path) else { return }
        do {
            try fm.moveItem(at: legacy, to: destination)
            NSLog("DictionaryStore: eski sözlük veritabanı \(destination.path) konumuna taşındı")
        } catch {
            // Taşıma başarısızsa yeni boş veritabanıyla devam edilir; arama bozulmaz.
            NSLog("DictionaryStore: eski veritabanı taşınamadı: \(error)")
        }
    }

    private func openIfNeeded() -> Bool {
        if db != nil { return true }
        if didAttemptOpen { return false }
        didAttemptOpen = true
        do {
            let support = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask,
                     appropriateFor: nil, create: true)
            let dir = support.appendingPathComponent("Kamus", isDirectory: true)
            migrateLegacyDirectory(from: support.appendingPathComponent("TDKDictionary",
                                                                       isDirectory: true), to: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let path = dir.appendingPathComponent("dictionary.sqlite").path

            var handle: OpaquePointer?
            guard sqlite3_open_v2(path, &handle,
                                  SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
                  let handle = handle else {
                if let handle = handle { sqlite3_close(handle) }
                NSLog("DictionaryStore: veritabanı açılamadı: \(path)")
                return false
            }
            db = handle
            exec("PRAGMA journal_mode=WAL;")
            exec("PRAGMA busy_timeout=2000;")
            exec("PRAGMA synchronous=NORMAL;")
            // COLLATE NOCASE bilerek kullanılmıyor: SQLite yalnızca ASCII katlar ve I→i yapar,
            // Türkçe I→ı kuralını bozar. Kanonikleştirme tr_TR lowercase ile kod tarafında yapılır.
            exec("""
                CREATE TABLE IF NOT EXISTS words (
                    id                INTEGER PRIMARY KEY AUTOINCREMENT,
                    word              TEXT NOT NULL UNIQUE,
                    response_json     TEXT NOT NULL,
                    first_searched_at REAL NOT NULL,
                    last_searched_at  REAL NOT NULL,
                    search_count      INTEGER NOT NULL DEFAULT 1
                );
                """)
            return true
        } catch {
            NSLog("DictionaryStore: açılış hatası: \(error)")
            return false
        }
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            if let err = err {
                NSLog("DictionaryStore: \(String(cString: err))")
                sqlite3_free(err)
            }
        }
    }

    private func logError(_ context: String) {
        let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "db yok"
        NSLog("DictionaryStore \(context): \(message)")
    }
}
