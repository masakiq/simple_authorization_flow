require 'webrick'
require 'json/jwt'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

server = WEBrick::HTTPServer.new :Port => 5001

class Authorization < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response_type = request.query['response_type']
    response_mode = request.query['response_mode']
    client_id = request.query['client_id']
    redirect_uri = request.query['redirect_uri']

    $key = OpenSSL::PKey::RSA.new(2048)
    claim = {
      'iss' => 'iss',
      'aud' => client_id,
      'exp' => Time.now.to_i + 3600,
      'iat' => Time.now.to_i,
      'sub' => ENV['SAF_USER_SUB'],
      'nonce' => 'nonce'
    }
    id_token = JSON::JWT.new(claim).sign($key, :RS256).to_s

    # check client_id & callback
    if response_type == 'id_token' && response_mode == 'form_post' && client_id == ENV['SAF_CLIENT_ID'] && redirect_uri == "#{ENV['SOCIAL_URI']}/callback"
      response.status = 200
      response['Content-Type'] = 'text/html'
      body = "
        <form action='#{redirect_uri}' method='post'>
          <input type='hidden' name='redirect_uri' id='redirect_uri' value='#{redirect_uri}'>
          <input type='hidden' name='id_token' id='id_token' value='#{id_token}'>
          <button style='width:100;height:50;'>permit</button>
        </form>
        </br>
        <form action='#{redirect_uri}' method='post'>
          <input type='hidden' name='redirect_uri' id='redirect_uri' value='#{redirect_uri}'>
          <input type='hidden' name='deny' id='deny' value='true'>
          <button style='width:100;height:50;'>deny</button>
        </form>
      "
      response.body = body
    else
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'invalid access'
    end
  end
end

class PublicKey < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = $key.public_key.to_s
  end
end

server.mount '/authorization', Authorization
server.mount '/public_key', PublicKey
server.start
