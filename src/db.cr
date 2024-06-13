require "sqlite3"

class DBHandler
  DB_PATH = "sqlite3://#{__DIR__}/../db/echo_pages.db"
  TABLE   = "pages"

  def initialize
    DB.open(DB_PATH) do |db|
      create_table(db) unless table_exists?(db)
    end
  end

  def create_table(db)
    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS #{TABLE} (
        id CHAR(36) PRIMARY KEY,
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    SQL
  end

  def table_exists?(db) : Bool
    db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='#{TABLE}'") do |rs|
      !rs.read.nil?
    end
  end

  def pages : Array(NamedTuple(id: String, created_at: Time))
    DB.open(DB_PATH) do |db|
      db.query_all("SELECT id, created_at FROM #{TABLE} ORDER BY created_at DESC", as: {id: String, created_at: Time})
    end
  end

  def create_page(content : String) : String
    uuid = UUID.random.to_s

    DB.open(DB_PATH) do |db|
      db.exec("INSERT INTO #{TABLE} (id, content) values (?, ?)", uuid, content)
    end
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=6)

    uuid
  end

  def update_page(uuid : String, content : String) : DB::ExecResult
    DB.open(DB_PATH) do |db|
      db.exec("UPDATE #{TABLE} SET content = ? WHERE id = ?", content, uuid)
    end
  end

  def get_page_content(uuid : String) : String?
    DB.open(DB_PATH) do |db|
      db.query_one?("SELECT content FROM #{TABLE} WHERE id = ?", uuid, as: String)
    end
  end

  def delete_page(uuid) : DB::ExecResult
    DB.open(DB_PATH) do |db|
      db.exec("DELETE FROM #{TABLE} WHERE id = ?", uuid)
    end
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=0)
  end
end
