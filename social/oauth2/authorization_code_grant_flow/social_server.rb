require 'webrick'
require 'net/http'

server = WEBrick::HTTPServer.new :Port => 5003

class Authentication < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    callback = "#{ENV['SOCIAL_URI']}/callback"
    client_id = ENV['SAF_CLIENT_ID']
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization?"\
      'response_type=code'\
      "&client_id=#{client_id}"\
      "&redirect_uri=#{callback}"

    response.status = 302
    response['Location'] = location
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    code = request.query['code']
    callback = "#{ENV['SOCIAL_URI']}/callback"

    if code&.size.to_i > 0
      token_uri =
        "#{ENV['SAF_AUTH_SERVER_URI']}/token"\
        "?grant_type=authorization_code"\
        "&code=#{code}"\
        "&redirect_uri=#{callback}"
      res = Net::HTTP.get_response(URI.parse(token_uri)).body
      access_token = res.split(',').first.match(/access_token:(?<token>.+)/)[:token]

      user_info_uri = "#{ENV['RESOURCE_URI']}/user_info?access_token=#{access_token}"
      user_info = Net::HTTP.get_response(URI.parse(user_info_uri)).body

      response.status = 302
      response['Location'] = "#{ENV['CLIENT_URI']}/finish?user_info=#{user_info}"
    else
      response.status = 302
      response['Location'] = "#{ENV['CLIENT_URI']}/finish?authorization=failed"
    end
  end
end

server.mount '/authorization', Authentication
server.mount '/callback', Callback
server.start
