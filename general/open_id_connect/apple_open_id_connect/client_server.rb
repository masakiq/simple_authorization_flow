require 'webrick'
require 'net/http'
require 'json/jwt'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

server = WEBrick::HTTPServer.new :Port => 5000

class Root < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    client_id = ENV['CLIENT_ID']
    callback = "#{ENV['CLIENT_URI']}/callback"
    location =
      "#{ENV['AUTH_URI']}/authorization?"\
      'response_type=id_token'\
      '&response_mode=form_post'\
      "&client_id=#{client_id}"\
      "&redirect_uri=#{callback}"

    response.status = 200
    response['Content-Type'] = 'text/html'
    body = "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{location}\"'>SIWA</button>"
    response.body = body
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    id_token = request.body.match(/\A(.+?)id_token=(?<id_token>.+?)\z/)[:id_token] if request.body.include?('id_token=')

    if id_token&.size.to_i > 0
      public_key_uri = "#{ENV['AUTH_URI']}/public_key"
      res = Net::HTTP.get_response(URI.parse(public_key_uri)).body
      public_key = OpenSSL::PKey::RSA.new(res)
      claims = JSON::JWT.decode(id_token, public_key)

      response.status = 302
      response['Location'] = "#{ENV['POTAL_URI']}/finish?user_info=#{claims[:sub]}"
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
