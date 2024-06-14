require "ecr"
require "uuid"
require "html"
require "http/server"
require "./db"
require "./helpers"

db_handler = DBHandler.new

server = HTTP::Server.new do |context|
  case context.request.path
  when "/"
    case context.request.method
    when "POST"
      title = context.request.form_params["title"]
      content = context.request.form_params["content"]

      if title && content
        id = db_handler.create_page(title, content)

        context.response.redirect("/pages/#{id}")
      else
        context.response.respond_with_status(:bad_request, "Bad Request: No body provided")
      end
    when "GET"
      context.response.print ECR.render("#{__DIR__}/views/index.ecr")
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
        total_entries = db_handler.pages_count
        per_page = 100

        total_pages = (total_entries // per_page) + (total_entries % per_page > 0 ? 1 : 0)

        pages = db_handler.pages(current_page, per_page)

        if pages.empty?
          context.response.respond_with_status(:not_found)
        else
          context.response.print ECR.render("#{__DIR__}/views/admin/pages/index.ecr")
        end
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/edit\/?$/
    case context.request.method
    when "GET"
      id = $1

      if page = db_handler.page(id)
        context.response.print ECR.render("#{__DIR__}/views/admin/pages/edit.ecr")
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

      db_handler.delete_page(id)

      context.response.redirect("/admin/pages")
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/?$/
    case context.request.method
    when "POST"
      id = $1

      title = context.request.form_params["title"]
      content = context.request.form_params["content"]

      if title && content
        db_handler.update_page(id, title, content)

        context.response.redirect("/pages/#{id}")
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
