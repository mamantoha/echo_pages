require "ecr"
require "uuid"
require "html"
require "http/server"
require "./db"

db_handler = DBHandler.new

server = HTTP::Server.new do |context|
  case context.request.path
  when "/"
    if context.request.method == "POST"
      if html_content = context.request.form_params["html_content"]
        id = db_handler.save_html(html_content)

        context.response.redirect("/pages/#{id}")
      else
        context.response.respond_with_status(:bad_request, "Bad Request: No body provided")
      end
    else
      context.response.print ECR.render("#{__DIR__}/views/index.ecr")
    end
  when /^\/pages\/(.*)/
    uuid = $1

    if html_content = db_handler.get_html(uuid)
      context.response.content_type = "text/html"
      context.response.print html_content
    else
      context.response.respond_with_status(:not_found, "Page not found")
    end
  when /^\/admin\/pages(\/)?$/
    if context.request.method == "GET"
      pages = db_handler.pages

      context.response.print ECR.render("#{__DIR__}/views/admin/pages/index.ecr")
    else
      context.response.respond_with_status(:not_found)
    end
  when /^\/admin\/pages\/(.*)\/edit(\/)?$/
    if context.request.method == "GET"
      uuid = $1

      if html_content = db_handler.get_html(uuid)
        context.response.print ECR.render("#{__DIR__}/views/admin/pages/edit.ecr")
      else
        context.response.respond_with_status(:not_found, "Page not found")
      end
    else
      context.response.respond_with_status(:not_found)
    end
  when /^\/admin\/pages\/(.*)(\/)?$/
    if context.request.method == "POST"
      uuid = $1

      if html_content = context.request.form_params["html_content"]
        db_handler.update_html(uuid, html_content)

        context.response.redirect("/pages/#{uuid}")
      end
    else
      context.response.respond_with_status(:not_found)
    end
  else
    context.response.respond_with_status(:not_found)
  end
end

address = server.bind_tcp(3001)
puts "Listening on http://#{address}"
server.listen
