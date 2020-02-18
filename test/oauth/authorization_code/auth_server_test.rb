require 'test/unit'
require 'net/http'
require 'pry'

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
    result = `ps aux | grep 'ruby test/mock/resource_server_mock.rb' | grep -v grep`
    `kill #{ result.split(' ')[1] } > /dev/null 2>&1`
  end

  def start_server
    env =
      'SAF_AUTH_SERVER_URI=http://localhost:10001 '\
      'SAF_RESOURCE_SERVER_URI=http://localhost:10002 '\
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

  def start_resource_server_mock(status:, response:)
    env =
      'SAF_RESOURCE_SERVER_URI=http://localhost:10002 '
    `#{env}ruby test/mock/resource_server_mock.rb #{status} #{response} > /dev/null 2>&1 &`
    while true do
      begin
        Net::HTTP.get_response(URI.parse('http://localhost:10002/heart_beat'))
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

  def test_permit
    url =
      'http://localhost:10001/permit'\
      '?redirect_uri=http://localhost:10002/callback'\
      '&state=state'
    res = Net::HTTP.get_response(URI.parse(url))
    assert_equal(res.code, '302')
    location = res.to_hash['location'].first
    uri = URI.parse(location)
    assert_equal(uri.port, 10002)
    assert_equal(uri.host, 'localhost')
    assert_equal(uri.path, '/callback')
    assert_equal(uri.query.include?("code=#{$auth_code}"), true)
    assert_equal(uri.query.include?('state=state'), true)
  end

  def test_deny
    url =
      'http://localhost:10001/deny'\
      '?redirect_uri=http://localhost:10002/callback'
    res = Net::HTTP.get_response(URI.parse(url))
    assert_equal(res.code, '302')
    location = res.to_hash['location'].first
    uri = URI.parse(location)
    assert_equal(uri.port, 10002)
    assert_equal(uri.host, 'localhost')
    assert_equal(uri.path, '/callback')
    assert_equal(uri.query.include?('deny=true'), true)
  end

  def prepare_permit
    uri =
      'http://localhost:10001/permit'\
      '?redirect_uri=http://localhost:10002/callback'\
      '&state=state'
    res = Net::HTTP.get_response(URI.parse(uri))
    location = res.to_hash['location'].first
    URI.parse(location).query.split('&').inject({}) { |r, q| r.merge(q.split('=')[0] => q.split('=')[1]) }
  end

  def test_token
    start_resource_server_mock(status: 200, response: 'token')
    params = prepare_permit

    uri = URI('http://localhost:10001/token')
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'authorization_code',
      code: params['code'],
      redirect_uri: 'http://localhost:10003/callback'
    )
    assert_equal(res.code, '200')
    assert_equal(res.body, 'token')
  end

  def test_token_auth_code_is_not_generated
    start_resource_server_mock(status: 200, response: 'token')

    uri = URI('http://localhost:10001/token')
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'authorization_code',
      code: 'code',
      redirect_uri: 'http://localhost:10003/callback'
    )
    assert_equal(res.code, '400')
    assert_equal(res.body, 'Not allow request token directly')
  end

  def test_token_invalid_auth_code
    start_resource_server_mock(status: 200, response: 'token')
    params = prepare_permit

    uri = URI('http://localhost:10001/token')
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'authorization_code',
      code: 'invalid' + params['code'],
      redirect_uri: 'http://localhost:10003/callback'
    )
    assert_equal(res.code, '400')
    assert_equal(res.body, 'Invalid auth_code')
  end

  def test_token_invalid_grant_type
    start_resource_server_mock(status: 200, response: 'token')
    params = prepare_permit

    uri = URI('http://localhost:10001/token')
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'password',
      code: params['code'],
      redirect_uri: 'http://localhost:10003/callback'
    )
    assert_equal(res.code, '400')
    assert_equal(res.body, 'Invalid grant_type')
  end

  def test_token_invalid_redirect_uri
    start_resource_server_mock(status: 200, response: 'token')
    params = prepare_permit

    uri = URI('http://localhost:10001/token')
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'authorization_code',
      code: params['code'],
      redirect_uri: 'http://localhost:10003/invalid'
    )
    assert_equal(res.code, '400')
    assert_equal(res.body, 'Invalid redirect_uri')
  end

  def test_token_deny_resource_server_access
    start_resource_server_mock(status: 400, response: 'invalid access')
    params = prepare_permit

    uri = URI('http://localhost:10001/token')
    res = Net::HTTP.post_form(
      uri,
      grant_type: 'authorization_code',
      code: params['code'],
      redirect_uri: 'http://localhost:10003/callback'
    )
    assert_equal(res.code, '500')
    assert_equal(res.body, 'Internal server error')
  end
end
