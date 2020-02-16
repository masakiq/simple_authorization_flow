require 'webrick'
require 'net/http'

client_port = ENV['SAF_CLIENT_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => client_port

class Root < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    client_id = ENV['SAF_CLIENT_ID']
    callback = "#{ENV['SAF_CLIENT_SERVER_URI']}/callback"
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization?"\
      'response_type=code&'\
      "client_id=#{client_id}&"\
      "redirect_uri=#{callback}"

    response.status = 200
    response['Content-Type'] = 'text/html'
    body = "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{location}\"'>LINE Login</button>"
    response.body = body
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    callback = "#{ENV['SAF_CLIENT_SERVER_URI']}/callback"
    code = request.query['code']

    if code&.size.to_i > 0
      token_uri =
        "#{ENV['SAF_AUTH_SERVER_URI']}/token"\
        "?grant_type=authorization_code"\
        "&code=#{code}"\
        "&redirect_uri=#{callback}"
      res = Net::HTTP.get_response(URI.parse(token_uri)).body
      access_token = res.split(',').first.match(/access_token:(?<token>.+)/)[:token]

      user_info_uri = "#{ENV['SAF_RESOURCE_SERVER_URI']}/user_info?access_token=#{access_token}"
      user_info = Net::HTTP.get_response(URI.parse(user_info_uri)).body

      response.status = 302
      response['Location'] = "/finish?user_info=#{user_info}"
    else
      response.status = 302
      response['Location'] = '/finish?authorization=failed'
    end
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
server.mount '/callback', Callback
server.mount '/finish', Finish
server.start
