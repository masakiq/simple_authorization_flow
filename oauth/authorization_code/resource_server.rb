require 'webrick'
require 'securerandom'

resource_port = ENV['SAF_RESOURCE_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => resource_port

class IssueToken < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    params = request.body.split('&').inject({}) { |r, q| r.merge(q.split('=')[0] => q.split('=')[1]) }
    if params['private_token'] == 'private_token'
      $token = SecureRandom.urlsafe_base64(20)
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = $token
    else
      $token = nil
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'invalid access token'
    end
  end
end

class UserInfo < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    if !$token.nil? && request.query['access_token'] == $token
      response.status = 200
      response['Content-Type'] = 'text/plain'
      response.body = ENV['SAF_USER_SUB']
    else
      response.status = 400
      response['Content-Type'] = 'text/plain'
      response.body = 'invalid access token'
    end
  end
end

server.mount '/issue_token', IssueToken
server.mount '/user_info', UserInfo
server.start
