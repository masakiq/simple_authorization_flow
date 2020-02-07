require 'webrick'
require 'net/http'

server = WEBrick::HTTPServer.new :Port => 5000

class Root < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    client_id = ENV['CLIENT_ID']
    callback = "#{ENV['CLIENT_URI']}/callback"
    location =
      "#{ENV['AUTH_URI']}/authorization?"\
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
    callback = "#{ENV['CLIENT_URI']}/callback"
    code = request.query['code']

    if code&.size.to_i > 0
      token_uri =
        "#{ENV['AUTH_URI']}/token"\
        "?grant_type=authorization_code"\
        "&code=#{code}"\
        "&redirect_uri=#{callback}"
      res = Net::HTTP.get_response(URI.parse(token_uri)).body
      access_token = res.split(',').first.match(/access_token:(?<token>.+)/)[:token]

      user_info_uri = "#{ENV['RESOURCE_URI']}/user_info?access_token=#{access_token}"
      user_info = Net::HTTP.get_response(URI.parse(user_info_uri)).body

      response.status = 302
      response['Location'] = "#{ENV['POTAL_URI']}/finish?user_info=#{user_info}"
    else
      response.status = 302
      response['Location'] = "#{ENV['POTAL_URI']}/finish?authorization=failed"
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
