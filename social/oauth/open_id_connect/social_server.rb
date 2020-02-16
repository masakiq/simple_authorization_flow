require 'webrick'
require 'net/http'
require 'json/jwt'
require 'securerandom'
STDOUT.sync = true
STDERR.sync = true
STDOUT.flush
STDERR.flush

social_port = ENV['SAF_SOCIAL_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => social_port

class Authentication < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    client_id = ENV['SAF_CLIENT_ID']
    callback = "#{ENV['SAF_SOCIAL_SERVER_URI']}/callback"
    $state = SecureRandom.urlsafe_base64(10)
    $nonce = SecureRandom.urlsafe_base64(10)
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization?"\
      'response_type=id_token'\
      '&response_mode=form_post'\
      "&client_id=#{client_id}"\
      "&redirect_uri=#{callback}"\
      "&state=#{$state}"\
      "&nonce=#{$nonce}"

    response.status = 302
    response['Location'] = location
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    params = request.body.split('&').inject({}) { |r, q| r.merge(q.split('=')[0] => q.split('=')[1]) }

    response.status = 302

    if params['id_token']&.size.to_i == 0 || params['state'] != $state
      response['Location'] = "#{ENV['SAF_CLIENT_SERVER_URI']}/finish?authorization=failed"
      return
    end

    public_key_uri = "#{ENV['SAF_AUTH_SERVER_URI']}/public_key"
    res = Net::HTTP.get_response(URI.parse(public_key_uri)).body
    public_key = OpenSSL::PKey::RSA.new(res)
    claims = JSON::JWT.decode(params['id_token'], public_key)

    failed_message = []
    failed_message << 'Client_id is different' if claims['aud'] != ENV['SAF_CLIENT_ID']
    failed_message << 'ID Token already expired' if claims[:exp] < Time.now.to_i
    failed_message << 'Nonce is defferent' if claims[:nonce] != $nonce

    if failed_message.size == 0
      response['Location'] = "#{ENV['SAF_CLIENT_SERVER_URI']}/finish?user_info=#{claims[:sub]}"
    else
      message = failed_message.join('+')
      response['Location'] = "#{ENV['SAF_CLIENT_SERVER_URI']}/finish?authorization=failed&message=#{message}"
    end
  end
end

server.mount '/authorization', Authentication
server.mount '/callback', Callback
server.start
