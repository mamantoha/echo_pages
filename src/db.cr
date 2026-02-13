require "sqlite3"

DB_PATH = "sqlite3://#{__DIR__}/../db/echo_pages.db"
SQL     = ::DB.open(DB_PATH)

Log.setup("db, http.server", :debug)

class Page
  include DB::Serializable

  TABLE = "pages"

  property id : String
  property title : String
  property content : String
  property created_at : Time

  def self.find(id : String) : Page?
    SQL.query_one?("SELECT id, title, content, created_at FROM #{TABLE} WHERE id = ?", id, as: Page)
  end

  def self.all(limit : Int32, offset : Int32) : Array(Page)
    SQL.query_all(
      "SELECT id, title, content, created_at FROM #{TABLE} ORDER BY created_at DESC LIMIT ? OFFSET ?",
      limit, offset,
      as: Page
    )
  end

  def self.count : Int64
    SQL.scalar("SELECT COUNT(*) FROM #{TABLE}").as(Int64)
  end

  def self.create(**args) : Page
    id = UUID.random.to_s

    SQL.query_one(
      "INSERT INTO #{TABLE} (id, title, content) VALUES (?, ?, ?) RETURNING *",
      id, args[:title], args[:content],
      as: Page
    )
  end

  def self.update(id : String, **args) : DB::ExecResult
    SQL.exec(
      "UPDATE #{TABLE} SET title = ?, content = ? WHERE id = ?",
      args[:title], args[:content], id
    )
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=0)
  end

  def self.delete(id : String) : DB::ExecResult
    SQL.exec("DELETE FROM #{TABLE} WHERE id = ?", id)
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=0)
  end
end

class DBHandler
  TABLE = "pages"

  def initialize
    DB.open(DB_PATH) do |db|
      create_table(db) unless table_exists?(db)
    end
  end

  private def create_table(db)
    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS #{TABLE} (
        id CHAR(36) PRIMARY KEY,
        title CHAR(256) NOT NULL,
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
      SQL
  end

  private def table_exists?(db) : Bool
    db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='#{TABLE}'") do |rs|
      !rs.read.nil?
    end
  end
end
