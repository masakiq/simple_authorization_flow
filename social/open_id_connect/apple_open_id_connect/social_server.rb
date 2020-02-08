require 'webrick'
require 'net/http'
require 'json/jwt'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

server = WEBrick::HTTPServer.new :Port => 5003

class Authentication < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    callback = "#{ENV['SOCIAL_URI']}/callback"
    client_id = ENV['CLIENT_ID']
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization?"\
      'response_type=id_token'\
      '&response_mode=form_post'\
      "&client_id=#{client_id}"\
      "&redirect_uri=#{callback}"

    response.status = 302
    response['Location'] = location
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    id_token = request.body.match(/\A(.+?)id_token=(?<id_token>.+?)\z/)[:id_token] if request.body.include?('id_token=')

    if id_token&.size.to_i > 0
      public_key_uri = "#{ENV['SAF_AUTH_SERVER_URI']}/public_key"
      res = Net::HTTP.get_response(URI.parse(public_key_uri)).body
      public_key = OpenSSL::PKey::RSA.new(res)
      claims = JSON::JWT.decode(id_token, public_key)

      response.status = 302
      response['Location'] = "#{ENV['CLIENT_URI']}/finish?user_info=#{claims[:sub]}"
    else
      response.status = 302
      response['Location'] = "#{ENV['CLIENT_URI']}/finish?authorization=failed"
    end
  end
end

server.mount '/authorization', Authentication
server.mount '/callback', Callback
server.start
