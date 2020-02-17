require 'webrick'
require 'net/http'
require 'json/jwt'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

client_port = ENV['SAF_CLIENT_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => client_port

class Root < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response['Content-Type'] = 'text/html'
    location = "#{ENV['SAF_SOCIAL_SERVER_URI']}/authorization"
    body = '<link rel="icon" href="data:,">'
    body << "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{location}\"'>Login</button>"
    response.body = body
  end
end

class Finish < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response['Content-Type'] = 'text/html'
    body = '<link rel="icon" href="data:,">'

    if request.query['user_info']&.size.to_i > 0
      body << "Finish, user_info: #{request.query['user_info']}"
    else
      body << 'Finish, authorization failed'
    end

    body << "<button type='button' style='width:100;height:50;' onclick='location.href=\"/\"'>again</button>"
    response.body = body
  end
end

server.mount '/', Root
server.mount '/finish', Finish
server.start
