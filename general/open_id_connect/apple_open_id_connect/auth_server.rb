require 'webrick'
require 'json/jwt'
require 'securerandom'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

auth_port = ENV['SAF_AUTH_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => auth_port
$key = OpenSSL::PKey::RSA.new(2048).freeze

class Authorization < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response_type = request.query['response_type']
    response_mode = request.query['response_mode']
    client_id = request.query['client_id']
    redirect_uri = request.query['redirect_uri']

    if response_type != 'id_token' || response_mode != 'form_post' && client_id != ENV['SAF_CLIENT_ID'] && redirect_uri != "#{ENV['SAF_CLIENT_SERVER_URI']}/callback"
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'invalid access'
      return
    end

    $one_time_token = SecureRandom.urlsafe_base64(20)
    token = {
      'exp' => Time.now.to_i + 300,
      'one_time_token' => $one_time_token,
      'client_ie' => client_id,
      'redirect_uri' => redirect_uri
    }
    signed_token = JSON::JWT.new(token).sign($key, :RS256).to_s

    response.status = 200
    response['Content-Type'] = 'text/html'
    body = "
      <form action='/permit' method='post'>
        <input type='hidden' name='token' id='token' value='#{signed_token}'>
        <button style='width:100;height:50;'>permit</button>
      </form>
      <form action='#{redirect_uri}' method='post'>
        <input type='hidden' name='deny' id='deny' value='true'>
        <button style='width:100;height:50;'>deny</button>
      </form>
    "
    response.body = body
  end
end

class Permit < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    one_time_token = $one_time_token
    $one_time_token = nil

    params = request.body.split('&').inject({}) { |r, q| r.merge(q.split('=')[0] => q.split('=')[1]) }

    token = JSON::JWT.decode(params['token'], $key.public_key)

    if token[:exp] < Time.now.to_i || token[:one_time_token] != one_time_token
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'failed permit'
      return
    end

    claim = {
      'iss' => 'iss',
      'aud' => token[:client_id],
      'exp' => Time.now.to_i + 3600,
      'iat' => Time.now.to_i,
      'sub' => ENV['SAF_USER_SUB'],
      'nonce' => 'nonce'
    }
    id_token = JSON::JWT.new(claim).sign($key, :RS256).to_s

    response.status = 200
    response['Content-Type'] = 'text/html'
    body = "
      <body onload='javascript:document.forms[0].submit()'>
      <form action='#{token[:redirect_uri]}' method='post'>
        <input type='hidden' name='id_token' id='id_token' value='#{id_token}'>
      </form>
    "
    response.body = body
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
server.mount '/permit', Permit
server.mount '/public_key', PublicKey
server.start
