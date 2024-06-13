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

  def pages : Array(NamedTuple(id: String, title: String, created_at: Time))
    DB.open(DB_PATH) do |db|
      db.query_all(
        "SELECT id, title, created_at FROM #{TABLE} ORDER BY created_at DESC",
        as: {id: String, title: String, created_at: Time}
      )
    end
  end

  def create_page(title : String, content : String) : String
    id = UUID.random.to_s

    DB.open(DB_PATH) do |db|
      db.exec("INSERT INTO #{TABLE} (id, title, content) values (?, ?, ?)", id, title, content)
    end
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=6)

    id
  end

  def update_page(id : String, title : String, content : String) : DB::ExecResult
    DB.open(DB_PATH) do |db|
      db.exec("UPDATE #{TABLE} SET title = ?, content = ? WHERE id = ?", title, content, id)
    end
  end

  def get_page(id : String) : NamedTuple(title: String, content: String)?
    DB.open(DB_PATH) do |db|
      db.query_one?("SELECT title, content FROM #{TABLE} WHERE id = ?", id, as: {title: String, content: String})
    end
  end

  def delete_page(id) : DB::ExecResult
    DB.open(DB_PATH) do |db|
      db.exec("DELETE FROM #{TABLE} WHERE id = ?", id)
    end
    # => DB::ExecResult(@rows_affected=1, @last_insert_id=0)
  end
end
