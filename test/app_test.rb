# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["GITHUB_CLIENT_ID"] = "test-client-id"
ENV["GITHUB_CLIENT_SECRET"] = "test-client-secret"
ENV["ALLOWED_ORIGINS"] = "https://example.org, https://preview.example.org"

require "minitest/autorun"
require "rack/test"
require "webmock/minitest"
require_relative "../app"

class DecapOAuthProxyTest < Minitest::Test
  include Rack::Test::Methods

  def app
    DecapOAuthProxy
  end

  def setup
    clear_cookies
  end

  def test_root_answers_ok
    get "/"
    assert_equal 200, last_response.status
  end

  def test_auth_redirects_to_github_with_state_and_cookie
    get "/auth", provider: "github", scope: "repo"

    assert_equal 302, last_response.status
    location = URI(last_response.headers["Location"])
    query = URI.decode_www_form(location.query).to_h

    assert_equal "github.com", location.host
    assert_equal "/login/oauth/authorize", location.path
    assert_equal "test-client-id", query["client_id"]
    assert_equal "repo", query["scope"]
    assert_match(/\A\h{64}\z/, query["state"])

    cookie = last_response.headers["Set-Cookie"]
    assert_includes cookie, "oauth_state=#{query['state']}"
    assert_includes cookie, "path=/callback"
    assert_includes cookie.downcase, "httponly"
    assert_includes cookie.downcase, "samesite=lax"
  end

  def test_auth_rejects_other_providers_and_scopes
    get "/auth", provider: "gitlab"
    assert_equal 400, last_response.status

    get "/auth", provider: "github", scope: "repo,admin:org"
    assert_equal 400, last_response.status
  end

  def test_callback_rejects_missing_or_mismatched_state
    get "/callback", code: "abc", state: "whatever"
    assert_equal 400, last_response.status

    state = start_flow
    get "/callback", code: "abc", state: "#{state}x"
    assert_equal 400, last_response.status
  end

  def test_callback_exchanges_code_and_posts_token_to_allowed_origins_only
    state = start_flow
    stub = stub_request(:post, "https://github.com/login/oauth/access_token")
      .with(
        headers: { "Accept" => "application/json" },
        body: { client_id: "test-client-id", client_secret: "test-client-secret", code: "good-code" }
      )
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(access_token: "gho_secret", token_type: "bearer", scope: "repo")
      )

    get "/callback", code: "good-code", state: state

    assert_requested stub
    assert_equal 200, last_response.status
    assert_equal "no-store", last_response.headers["Cache-Control"]
    body = last_response.body

    assert_includes body, 'var allowedOrigins = ["https://example.org","https://preview.example.org"];'
    assert_includes body, 'var message = "authorization:github:success:{\"token\":\"gho_secret\",\"provider\":\"github\"}";'
    assert_includes body, "window.opener.postMessage(message, e.origin);"
    assert_includes body, 'window.opener.postMessage("authorizing:github", "*");'
    refute_includes body, 'postMessage(message, "*")'
    assert_includes last_response.headers["Set-Cookie"], "oauth_state=;"
  end

  def test_callback_reports_github_errors_to_the_cms
    state = start_flow
    get "/callback", error: "access_denied", error_description: "The user has denied", state: state

    assert_equal 200, last_response.status
    assert_includes last_response.body,
      'var message = "authorization:github:error:{\"message\":\"The user has denied\",\"provider\":\"github\"}";'
  end

  def test_callback_reports_failed_exchange_to_the_cms
    state = start_flow
    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                 body: JSON.generate(error: "bad_verification_code"))

    get "/callback", code: "stale", state: state

    assert_equal 200, last_response.status
    assert_includes last_response.body, "authorization:github:error:"
    refute_includes last_response.body, "success"
  end

  def test_callback_escapes_script_closing_sequences
    state = start_flow
    stub_request(:post, "https://github.com/login/oauth/access_token")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                 body: JSON.generate(access_token: "</script><script>alert(1)</script>"))

    get "/callback", code: "x", state: state

    refute_includes last_response.body, "</script><script>alert"
    assert_includes last_response.body, "\\u003c/script>"
  end

  private

  def start_flow
    get "/auth", provider: "github", scope: "repo"
    URI.decode_www_form(URI(last_response.headers["Location"]).query).to_h["state"]
  end
end
