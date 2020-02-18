require 'webrick'
require 'securerandom'
require 'net/http'

auth_port = ENV['SAF_AUTH_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => auth_port

class Authorization < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response_type = request.query['response_type']
    client_id = request.query['client_id']
    redirect_uri = request.query['redirect_uri']
    state = request.query['state']

    # check client_id & callback
    if response_type == 'code' && client_id == ENV['SAF_CLIENT_ID'] && redirect_uri == "#{ENV['SAF_REDIRECT_URI']}"
      response.status = 200
      response['Content-Type'] = 'text/html'
      body =
        "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{ENV['SAF_AUTH_SERVER_URI']}/permit?redirect_uri=#{redirect_uri}&state=#{state}\"'>permit</button>"\
        '</br> '\
        '</br> '\
        "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{ENV['SAF_AUTH_SERVER_URI']}/deny?redirect_uri=#{redirect_uri}\"'>deny</button>"
      response.body = body
    else
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'invalid access'
    end
  end
end

class Permit < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    $auth_code = SecureRandom.urlsafe_base64(16)
    redirect_uri = request.query['redirect_uri']
    state = request.query['state']
    response.status = 302
    response['Location'] = "#{redirect_uri}?code=#{$auth_code}&state=#{state}"
  end
end

class Deny < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    redirect_uri = request.query['redirect_uri']
    response.status = 302
    response['Location'] = "#{redirect_uri}?deny=true"
  end
end

class Token < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    params = request.body.split('&').inject({}) { |r, q| r.merge(q.split('=')[0] => q.split('=')[1]) }

    grant_type = params['grant_type']
    code = params['code']
    redirect_uri = URI.decode(params['redirect_uri'])

    response['Content-Type'] = 'text/plain'

    errors = []
    errors << 'Not allow request token directly' if $auth_code.nil?
    errors << 'Invalid auth_code' if code != $auth_code && errors.size == 0
    errors << 'Invalid grant_type' if grant_type != 'authorization_code'
    errors << 'Invalid redirect_uri' if redirect_uri != "#{ENV['SAF_REDIRECT_URI']}"
    if errors.size > 0
      response.status = 400
      response.body = errors.join(',')
      return
    end

    uri = URI("#{ENV['SAF_RESOURCE_SERVER_URI']}/issue_token")
    res = Net::HTTP.post_form(uri, private_token: 'private_token')
    if res.code == '200'
      response.status = 200
      response.body = res.body
    else
      response.status = 500
      response.body = 'Internal server error'
    end
  end
end

class HeartBeat < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = 'ok'
  end
end

server.mount '/authorization', Authorization
server.mount '/permit', Permit
server.mount '/deny', Deny
server.mount '/token', Token
server.mount '/heart_beat', HeartBeat
server.start
