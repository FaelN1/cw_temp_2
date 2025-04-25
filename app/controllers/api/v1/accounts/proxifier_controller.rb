require 'net/http'
require 'uri'
require 'json'

class Api::V1::Accounts::ProxifierController < Api::V1::Accounts::BaseController
  EVOLUTION_SERVER = 'https://api.salez.com.br' # URL fixa
  # EVOLUTION_SERVER = 'http://localhost:8080' # URL fixa
  EVOLUTION_APIKEY = '429683C4C977415CAAFCCE10F7D57333' # Token fixo



  def index
    render json: {
      status: "success",
      message: "internal api test"
    }
  end

  def evolution
    if EVOLUTION_SERVER.nil? || EVOLUTION_APIKEY.nil?
      render json: { status: "error", message: "EVOLUTION_API_URL or EVOLUTION_API_AUTHENTICATION_API_KEY is not configured" }, status: 500 and return
    end

    path = request.headers["path"]
    if path.blank?
      render json: { status: "error", message: "Empty Path" }, status: 400 and return
    end

    headers = {
      'Content-Type' => 'application/json',
      'apikey' => EVOLUTION_APIKEY
    }

    uri = URI.join(EVOLUTION_SERVER, path)
    response = forward_request(uri,headers)
    render json: response.body, status: response.code
  end

  private

  def forward_request(uri,headers)
    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == "https"
      http.use_ssl = true
    else
      http.use_ssl = false
    end

    net_http_request = build_request(uri, headers)

    response = http.request(net_http_request)

    Rails.logger.info('==================================')
    Rails.logger.info('Proxifier')
    Rails.logger.info(request.method)
    Rails.logger.info(uri)
    Rails.logger.info(net_http_request.body)
    Rails.logger.info(response.body)
    Rails.logger.info('==================================')

    response
  end

  def build_request(uri, headers)
    req = case request.method
          when 'GET' then Net::HTTP::Get.new(uri.request_uri)
          when 'POST' then Net::HTTP::Post.new(uri.request_uri)
          when 'PUT' then Net::HTTP::Put.new(uri.request_uri)
          when 'PATCH' then Net::HTTP::Patch.new(uri.request_uri)
          when 'DELETE' then Net::HTTP::Delete.new(uri.request_uri)
          else
            render json: { status: "error", message: "Unsupported HTTP method" }, status: 405 and return
          end

    req.body = request.body.read if %w[POST PUT PATCH].include?(request.method)
    headers.each { |key, value| req[key.to_s] = value }

    req
  end

end
