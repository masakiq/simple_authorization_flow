require 'webrick'
require 'net/http'
require 'securerandom'

client_port = ENV['SAF_CLIENT_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => client_port

class Root < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    client_id = ENV['SAF_CLIENT_ID']
    callback = "#{ENV['SAF_CLIENT_SERVER_URI']}/callback"
    $state = SecureRandom.urlsafe_base64(10)
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization"\
      '?response_type=code'\
      "&client_id=#{client_id}"\
      "&redirect_uri=#{callback}"\
      "&state=#{$state}"

    response.status = 200
    response['Content-Type'] = 'text/html'
    body = '<link rel="icon" href="data:,">'
    body << "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{location}\"'>Login</button>"
    response.body = body
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    callback = "#{ENV['SAF_CLIENT_SERVER_URI']}/callback"
    code = request.query['code']
    state = request.query['state']

    response.status = 302

    if $state.nil? || $state != state || code&.size.to_i == 0
      response['Location'] = '/finish?authorization=failed'
      return
    end

    token_uri =
      "#{ENV['SAF_AUTH_SERVER_URI']}/token"\
      "?grant_type=authorization_code"\
      "&code=#{code}"\
      "&redirect_uri=#{callback}"
    res = Net::HTTP.get_response(URI.parse(token_uri)).body
    access_token = res.split(',').first.match(/access_token:(?<token>.+)/)[:token]

    user_info_uri = "#{ENV['SAF_RESOURCE_SERVER_URI']}/user_info?access_token=#{access_token}"
    user_info = Net::HTTP.get_response(URI.parse(user_info_uri)).body

    response['Location'] = "/finish?user_info=#{user_info}"
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
server.mount '/callback', Callback
server.mount '/finish', Finish
server.start
