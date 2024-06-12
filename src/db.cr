require "sqlite3"

class DBHandler
  DB_PATH = "sqlite3://#{__DIR__}/../db/echo_pages.db"
  TABLE   = "html_pages"

  def initialize
    DB.open(DB_PATH) do |db|
      create_table(db) unless table_exists?(db)
    end
  end

  def create_table(db)
    db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS #{TABLE} (
        id CHAR(36) PRIMARY KEY,
        html_content TEXT NOT NULL,
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
    pages = [] of NamedTuple(id: String, created_at: Time)

    DB.open(DB_PATH) do |db|
      db.query("SELECT id, created_at FROM #{TABLE} ORDER BY created_at DESC") do |rs|
        rs.each do
          id = rs.read(String)
          created_at = rs.read(Time)

          pages << {id: id, created_at: created_at}
        end
      end
    end

    pages
  end

  def save_html(content : String) : String
    uuid = UUID.random.to_s

    DB.open(DB_PATH) do |db|
      db.exec("INSERT INTO #{TABLE} (id, html_content) values (?, ?)", uuid, content)

      uuid
    end
  end

  def get_html(uuid : String) : String?
    DB.open(DB_PATH) do |db|
      db.query_one?("SELECT html_content FROM #{TABLE} WHERE id = ?", uuid, as: String)
    end
  end
end
