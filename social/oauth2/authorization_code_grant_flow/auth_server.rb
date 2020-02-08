require 'webrick'

server = WEBrick::HTTPServer.new :Port => 5001

class Authorization < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response_type = request.query['response_type']
    client_id = request.query['client_id']
    redirect_uri = request.query['redirect_uri']

    # check client_id & callback
    if response_type == 'code' && client_id == ENV['SAF_CLIENT_ID'] && redirect_uri == "#{ENV['SAF_SOCIAL_SERVER_URI']}/callback"
      response.status = 200
      response['Content-Type'] = 'text/html'
      body =
        "<button type='button' style='width:100;height:50;' onclick='location.href=\"#{ENV['SAF_AUTH_SERVER_URI']}/permit?redirect_uri=#{redirect_uri}\"'>permit</button>"\
        '</br>'\
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
    redirect_uri = request.query['redirect_uri']
    response.status = 302
    response['Location'] = "#{redirect_uri}?code=#{ENV['SAF_AUTH_CODE']}"
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
  def do_GET request, response
    grant_type = request.query['grant_type']
    code = request.query['code']
    redirect_uri = request.query['redirect_uri']

    if grant_type == 'authorization_code' && request.query['code'] == ENV['SAF_AUTH_CODE'] && redirect_uri == "#{ENV['SAF_SOCIAL_SERVER_URI']}/callback"
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = "access_token:#{ENV['SAF_AUTH_TOKEN']},token_tyep:Bearer"
    else
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'invalid auth_code'
    end
  end
end

server.mount '/authorization', Authorization
server.mount '/permit', Permit
server.mount '/deny', Deny
server.mount '/token', Token
server.start
