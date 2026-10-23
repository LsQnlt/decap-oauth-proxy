# frozen_string_literal: true

require "sinatra/base"
require "net/http"
require "json"
require "securerandom"
require "uri"

# GitHub OAuth proxy for Decap CMS and Sveltia CMS (backend "github").
#
# Protocol (what the CMS expects from `base_url`):
#   1. The CMS opens a popup on GET /auth?provider=github&scope=repo
#   2. We redirect to github.com/login/oauth/authorize with a random `state`
#   3. GitHub calls back GET /callback?code=...&state=...
#   4. We exchange the code for an access token and render a page that hands
#      the token to `window.opener` via postMessage, only to an allowed origin.
#
# Configuration, all through environment variables:
#   GITHUB_CLIENT_ID      OAuth App client id
#   GITHUB_CLIENT_SECRET  OAuth App client secret
#   ALLOWED_ORIGINS       comma-separated site origins allowed to receive a
#                         token, e.g. "https://example.org,https://preview.example.org"
class DecapOAuthProxy < Sinatra::Base
  GITHUB_AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
  GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
  ALLOWED_SCOPES = %w[repo public_repo].freeze
  STATE_COOKIE = "oauth_state"
  STATE_TTL = 600

  set :client_id, ENV.fetch("GITHUB_CLIENT_ID")
  set :client_secret, ENV.fetch("GITHUB_CLIENT_SECRET")
  set :allowed_origins, ENV.fetch("ALLOWED_ORIGINS").split(",").map(&:strip).reject(&:empty?)
  set :logging, true
  set :show_exceptions, false
  set :dump_errors, false

  get "/" do
    content_type :text
    "ok"
  end

  get "/auth" do
    provider = params.fetch("provider", "github")
    halt 400, "unsupported provider" unless provider == "github"

    scope = params.fetch("scope", "repo")
    halt 400, "unsupported scope" unless ALLOWED_SCOPES.include?(scope)

    state = SecureRandom.hex(32)
    response.set_cookie(
      STATE_COOKIE,
      value: state,
      path: "/callback",
      max_age: STATE_TTL,
      httponly: true,
      secure: request.ssl?,
      same_site: :lax
    )

    query = URI.encode_www_form(client_id: settings.client_id, scope: scope, state: state)
    redirect "#{GITHUB_AUTHORIZE_URL}?#{query}", 302
  end

  get "/callback" do
    expected_state = request.cookies[STATE_COOKIE].to_s
    response.delete_cookie(STATE_COOKIE, path: "/callback")

    state = params["state"].to_s
    halt 400, "invalid state" if state.empty? || expected_state.empty? ||
                                 !Rack::Utils.secure_compare(state, expected_state)

    message =
      if params["error"]
        error_message(params.fetch("error_description", params["error"]))
      else
        token = exchange_code(params["code"].to_s)
        token ? success_message(token) : error_message("token exchange failed")
      end

    headers "Cache-Control" => "no-store"
    content_type :html
    callback_page(message)
  end

  private

  def exchange_code(code)
    return nil if code.empty?

    uri = URI(GITHUB_TOKEN_URL)
    request = Net::HTTP::Post.new(uri)
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(
      client_id: settings.client_id,
      client_secret: settings.client_secret,
      code: code
    )

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end

    body = JSON.parse(response.body)
    return nil if body["error"] || body["access_token"].to_s.empty?

    body["access_token"]
  rescue JSON::ParserError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    logger.error("token exchange failed: #{e.class}")
    nil
  end

  def success_message(token)
    "authorization:github:success:#{JSON.generate(token: token, provider: 'github')}"
  end

  def error_message(detail)
    "authorization:github:error:#{JSON.generate(message: detail.to_s, provider: 'github')}"
  end

  # Embedded as JS string literals: escape "<" so a value can never close the script tag.
  def js(value)
    JSON.generate(value).gsub("<", "\\u003c")
  end

  def callback_page(message)
    <<~HTML
      <!doctype html>
      <html>
        <head>
          <meta charset="utf-8">
          <title>Authorization</title>
        </head>
        <body>
          <script>
            (function () {
              var allowedOrigins = #{js(settings.allowed_origins)};
              var message = #{js(message)};

              function receiveMessage(e) {
                if (e.source !== window.opener) return;
                if (e.data !== "authorizing:github") return;
                if (allowedOrigins.indexOf(e.origin) === -1) return;
                window.removeEventListener("message", receiveMessage, false);
                window.opener.postMessage(message, e.origin);
                window.close();
              }

              if (!window.opener) {
                document.body.textContent = "This page must be opened by the CMS login popup.";
                return;
              }
              window.addEventListener("message", receiveMessage, false);
              window.opener.postMessage("authorizing:github", "*");
            })();
          </script>
        </body>
      </html>
    HTML
  end
end
