require "sqlite3"

class Page
  include DB::Serializable

  property id : String
  property title : String
  property content : String
  property created_at : Time
end

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
        title CHAR(256) NOT NULL,
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

  def pages(page : Int32, per_page : Int32) : Array(Page)
    offset = (page - 1) * per_page

    DB.open(DB_PATH) do |db|
      rs = db.query(
        "SELECT id, title, content, created_at FROM #{TABLE} ORDER BY created_at DESC LIMIT ? OFFSET ?",
        per_page, offset
      )

      Page.from_rs(rs)
    end
  end

  def page(id : String) : Page?
    DB.open(DB_PATH) do |db|
      db.query_one?("SELECT id, title, content, created_at FROM #{TABLE} WHERE id = ?", id, as: Page)
    end
  end

  def pages_count : Int64
    DB.open(DB_PATH) do |db|
      db.scalar("SELECT COUNT(*) FROM #{TABLE}").as(Int64)
    end
  end

  def create_page(title : String, content : String) : String
    id = UUID.random.to_s

    DB.open(DB_PATH) do |db|
      db.exec("INSERT INTO #{TABLE} (id, title, content) VALUES (?, ?, ?)", id, title, content)
    end
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=6)

    id
  end

  def update_page(id : String, title : String, content : String) : DB::ExecResult
    DB.open(DB_PATH) do |db|
      db.exec("UPDATE #{TABLE} SET title = ?, content = ? WHERE id = ?", title, content, id)
    end
  end

  def delete_page(id) : DB::ExecResult
    DB.open(DB_PATH) do |db|
      db.exec("DELETE FROM #{TABLE} WHERE id = ?", id)
    end
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=0)
  end
end
