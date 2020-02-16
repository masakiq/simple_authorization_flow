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
    client_id = ENV['SAF_CLIENT_ID']
    callback = "#{ENV['SAF_CLIENT_SERVER_URI']}/callback"
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization?"\
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
    params = request.body.split('&').inject({}) { |r, q| r.merge(q.split('=')[0] => q.split('=')[1]) }

    if params['id_token']&.size.to_i == 0
      response.status = 302
      response['Location'] = "/finish?authorization=failed"
      return
    end

    public_key_uri = "#{ENV['SAF_AUTH_SERVER_URI']}/public_key"
    res = Net::HTTP.get_response(URI.parse(public_key_uri)).body
    public_key = OpenSSL::PKey::RSA.new(res)
    claims = JSON::JWT.decode(params['id_token'], public_key)

    failed_message = []
    failed_message << 'Client_id is different' if claims['aud'] != ENV['SAF_CLIENT_ID']
    failed_message << 'ID Token already expired' if claims[:exp] < Time.now.to_i

    response.status = 302
    if failed_message.size == 0
      response['Location'] = "/finish?user_info=#{claims[:sub]}"
    else
      message = failed_message.join('+')
      response['Location'] = "/finish?authorization=failed&message=#{message}"
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
