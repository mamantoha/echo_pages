require "uuid"
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
        context.response.status_code = 400
        context.response.print "Bad Request: No body provided"
      end
    else
      context.response.print <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>EchoPages</title>
        </head>
        <body>
          <header>
            <h2>Submit your HTML and instantly receive a URL to access it.</h2>
          </header>
          <main>
            <form action="/" method="post">
              <textarea name="html_content" rows="10" cols="50"></textarea><br>
              <input type="submit" value="Submit HTML">
            </form>
          </main>
          <footer>
            <p>Build with Crystal #{Crystal::VERSION} © 2024</p>
          </footer>
        </body>
      HTML
    end
  when /\/pages\/(.*)/
    uuid = $1

    if html_content = db_handler.get_html(uuid)
      context.response.content_type = "text/html"
      context.response.print html_content
    else
      context.response.status_code = 404
      context.response.print "Page not found"
    end
  else
    context.response.respond_with_status(:not_found)
  end
end

address = server.bind_tcp(3001)
puts "Listening on http://#{address}"
server.listen
