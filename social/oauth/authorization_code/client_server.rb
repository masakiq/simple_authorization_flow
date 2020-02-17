require 'webrick'
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
    body = '<link rel="icon" href="data:,">'
    location = "#{ENV['SAF_SOCIAL_SERVER_URI']}/authorization"
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
      body << "<p>Finish, user_info: #{request.query['user_info']}</p>"
    else
      body << '<p>Finish, authorization failed</p>'
    end

    body << "<button type='button' style='width:100;height:50;' onclick='location.href=\"/\"'>again</button>"
    response.body = body
  end
end

server.mount '/', Root
server.mount '/finish', Finish
server.start
