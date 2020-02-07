require 'webrick'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

server = WEBrick::HTTPServer.new :Port => 5000

class Root < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response['Content-Type'] = 'text/html'
    location = "#{ENV['SOCIAL_URI']}/authorization"
    body = "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{location}\"'>LINE Login</button>"
    response.body = body
  end
end

class Finish < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    if request.query['user_info']&.size.to_i > 0
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = "Finish, user_info: #{request.query['user_info']}"
    else
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = 'Finish, authorization failed'
    end
  end
end

server.mount '/', Root
server.mount '/finish', Finish
server.start
