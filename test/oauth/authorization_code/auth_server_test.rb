require 'test/unit'
require 'net/http'

class AuthServerTest < Test::Unit::TestCase
  def setup
    kill_server
    start_server
  end

  def teardown
    kill_server
  end

  def kill_server
    result = `ps aux | grep 'ruby oauth/authorization_code/auth_server.rb' | grep -v grep`
    `kill #{ result.split(' ')[1] } > /dev/null 2>&1`
  end

  def start_server
    env =
      'SAF_AUTH_SERVER_URI=http://localhost:10001 '\
      'SAF_CLIENT_ID=123 '\
      'SAF_REDIRECT_URI=http://localhost:10003/callback '
    `#{env}ruby oauth/authorization_code/auth_server.rb > /dev/null 2>&1 &`
    while true do
      begin
        Net::HTTP.get_response(URI.parse('http://localhost:10001/heart_beat'))
        break
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
    end
  end

  def test_authorization
    url =
      'http://localhost:10001/authorization'\
      '?response_type=code'\
      '&client_id=123'\
      '&redirect_uri=http://localhost:10003/callback'\
      '&state=state'
    res = Net::HTTP.get_response(URI.parse(url))
    assert_equal(res.code, '200')
  end

  def test_authorization_invalid_client_id
    url =
      'http://localhost:10001/authorization'\
      '?response_type=code'\
      '&client_id=abc'\
      '&redirect_uri=http://localhost:10003/callback'\
      '&state=state'
    res = Net::HTTP.get_response(URI.parse(url))
    assert_equal(res.code, '400')
  end

  def test_authorization_invalid_redirect_uri
    url =
      'http://localhost:10001/authorization'\
      '?response_type=code'\
      '&client_id=123'\
      '&redirect_uri=http://localhost:10002/callback'\
      '&state=state'
    res = Net::HTTP.get_response(URI.parse(url))
    assert_equal(res.code, '400')
  end
end
