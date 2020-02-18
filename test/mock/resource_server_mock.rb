require 'webrick'
require 'securerandom'

resource_port = ENV['SAF_RESOURCE_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => resource_port

class IssueToken < WEBrick::HTTPServlet::AbstractServlet
  def do_POST request, response
    response['Content-Type'] = 'text/plain'
    response.status = (ARGV[0] || 200).to_i
    response.body = ARGV[1] || 'token'
  end
end

class HeartBeat < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = 'ok'
  end
end

server.mount '/issue_token', IssueToken
server.mount '/heart_beat', HeartBeat
server.start
