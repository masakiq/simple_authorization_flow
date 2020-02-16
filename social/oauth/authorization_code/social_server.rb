require 'webrick'
require 'net/http'
require 'securerandom'

social_port = ENV['SAF_SOCIAL_SERVER_URI'].match(/\Ahttp:\/\/localhost:(?<port>.+?)\z/)[:port].to_i
server = WEBrick::HTTPServer.new :Port => social_port

class Authentication < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    client_id = ENV['SAF_CLIENT_ID']
    callback = "#{ENV['SAF_SOCIAL_SERVER_URI']}/callback"
    $state = SecureRandom.urlsafe_base64(10)
    location =
      "#{ENV['SAF_AUTH_SERVER_URI']}/authorization?"\
      'response_type=code'\
      "&client_id=#{client_id}"\
      "&redirect_uri=#{callback}"\
      "&state=#{$state}"

    response.status = 302
    response['Location'] = location
  end
end

class Callback < WEBrick::HTTPServlet::AbstractServlet
  def do_GET request, response
    callback = "#{ENV['SAF_SOCIAL_SERVER_URI']}/callback"
    code = request.query['code']
    state = request.query['state']

    response.status = 302

    if $state.nil? || $state != state || code&.size.to_i == 0
      response['Location'] = "#{ENV['SAF_CLIENT_SERVER_URI']}/finish?authorization=failed"
      return
    end

    uri = URI("#{ENV['SAF_AUTH_SERVER_URI']}/token")
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: callback
    )
    if res.code != '200'
      response['Location'] = "#{ENV['SAF_CLIENT_SERVER_URI']}/finish?authorization=failed&invalid_auth_code"
      return
    end

    access_token = res.body
    user_info_uri = "#{ENV['SAF_RESOURCE_SERVER_URI']}/user_info?access_token=#{access_token}"
    user_info = Net::HTTP.get_response(URI.parse(user_info_uri)).body

    response['Location'] = "#{ENV['SAF_CLIENT_SERVER_URI']}/finish?user_info=#{user_info}"
  end
end

server.mount '/authorization', Authentication
server.mount '/callback', Callback
server.start
