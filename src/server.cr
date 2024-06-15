require "ecr"
require "uuid"
require "html"
require "http/server"
require "./db"
require "./helpers"

module ECR
  macro render_with_block(layout, &block)
    content = {{ yield }}

    ECR.render {{layout}}
  end
end

class SessionStore
  SESSIONS = {} of String => Hash(String, String)

  def self.generate_csrf_token(session_id : String) : String
    token = Random::Secure.hex(16)
    session = SESSIONS[session_id] ||= {} of String => String
    session["csrf_token"] = token
    token
  end

  def self.valid_csrf_token?(session_id : String, token : String) : Bool
    session = SESSIONS[session_id]?
    session ? session["csrf_token"] == token : false
  end
end

db_handler = DBHandler.new

server = HTTP::Server.new(
  [
    HTTP::LogHandler.new,
    HTTP::CompressHandler.new,
  ]
) do |context|
  session_id =
    (context.request.cookies["session_id"]? && context.request.cookies["session_id"].value) ||
      Random::Secure.hex(16)

  context.response.cookies["session_id"] = HTTP::Cookie.new("session_id", session_id, http_only: true)

  case context.request.path
  when "/favicon.ico"
    icon_path = "#{__DIR__}/assets/images/favicon.ico"
    icon_content = File.read(icon_path)

    context.response.content_type = "image/x-icon"
    context.response.print icon_content
  when "/"
    case context.request.method
    when "GET"
      csrf_token = SessionStore.generate_csrf_token(session_id)
      page = nil

      content = ECR.render_with_block("#{__DIR__}/views/layouts/layout.ecr") do
        ECR.render("#{__DIR__}/views/index.ecr")
      end

      context.response.print content
    when "POST"
      csrf_token = context.request.form_params["csrf_token"]?

      if csrf_token && SessionStore.valid_csrf_token?(session_id, csrf_token)
        title = context.request.form_params["title"]
        content = context.request.form_params["content"]

        if title && content
          id = db_handler.create_page(title, content)

          context.response.redirect("/pages/#{id}")
        else
          context.response.respond_with_status(:bad_request, "Bad Request: No body provided")
        end
      else
        context.response.respond_with_status(:bad_request, "Invalid or missing CSRF token")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/pages\/(.*)/
    case context.request.method
    when "GET"
      id = $1

      if page = db_handler.page(id)
        context.response.content_type = "text/html; charset=utf-8"
        context.response.print page.content
      else
        context.response.respond_with_status(:not_found, "Page not found")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/?$/
    case context.request.method
    when "GET"
      current_page = (context.request.query_params["page"]? || "1").to_i

      if current_page < 1
        context.response.respond_with_status(:not_found)
      else
        csrf_token = SessionStore.generate_csrf_token(session_id)

        total_entries = db_handler.pages_count
        per_page = 100

        total_pages = (total_entries // per_page) + (total_entries % per_page > 0 ? 1 : 0)

        pages = db_handler.pages(current_page, per_page)

        content = ECR.render_with_block("#{__DIR__}/views/layouts/layout.ecr") do
          ECR.render("#{__DIR__}/views/admin/pages/index.ecr")
        end

        context.response.print content
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/edit\/?$/
    case context.request.method
    when "GET"
      id = $1

      if page = db_handler.page(id)
        csrf_token = SessionStore.generate_csrf_token(session_id)

        content = ECR.render_with_block("#{__DIR__}/views/layouts/layout.ecr") do
          ECR.render("#{__DIR__}/views/admin/pages/edit.ecr")
        end

        context.response.print content
      else
        context.response.respond_with_status(:not_found, "Page not found")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/delete\/?$/
    case context.request.method
    when "POST"
      id = $1

      csrf_token = context.request.form_params["csrf_token"]?

      if csrf_token && SessionStore.valid_csrf_token?(session_id, csrf_token)
        db_handler.delete_page(id)

        context.response.redirect("/admin/pages")
      else
        context.response.respond_with_status(:bad_request, "Invalid or missing CSRF token")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/?$/
    case context.request.method
    when "POST"
      id = $1

      csrf_token = context.request.form_params["csrf_token"]?

      if csrf_token && SessionStore.valid_csrf_token?(session_id, csrf_token)
        title = context.request.form_params["title"]
        content = context.request.form_params["content"]

        if title && content
          db_handler.update_page(id, title, content)

          context.response.redirect("/pages/#{id}")
        end
      else
        context.response.respond_with_status(:bad_request, "Invalid or missing CSRF token")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  else
    context.response.respond_with_status(:not_found)
  end
end

address = server.bind_tcp(3001)
puts "Listening on http://#{address}"
server.listen
