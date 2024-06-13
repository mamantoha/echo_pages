require "ecr"
require "uuid"
require "html"
require "http/server"
require "./db"

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
      uuid = $1

      if page = db_handler.get_page(uuid)
        context.response.content_type = "text/html; charset=utf-8"
        context.response.print page[:content]
      else
        context.response.respond_with_status(:not_found, "Page not found")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages(\/)?$/
    case context.request.method
    when "GET"
      pages = db_handler.pages

      context.response.print ECR.render("#{__DIR__}/views/admin/pages/index.ecr")
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/edit(\/)?$/
    case context.request.method
    when "GET"
      uuid = $1

      if page = db_handler.get_page(uuid)
        context.response.print ECR.render("#{__DIR__}/views/admin/pages/edit.ecr")
      else
        context.response.respond_with_status(:not_found, "Page not found")
      end
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)\/delete(\/)?$/
    case context.request.method
    when "POST"
      uuid = $1

      db_handler.delete_page(uuid)

      context.response.redirect("/admin/pages")
    else
      context.response.respond_with_status(:method_not_allowed)
    end
  when /^\/admin\/pages\/(.*)(\/)?$/
    case context.request.method
    when "POST"
      uuid = $1

      title = context.request.form_params["title"]
      content = context.request.form_params["content"]

      if title && content
        db_handler.update_page(uuid, title, content)

        context.response.redirect("/pages/#{uuid}")
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
