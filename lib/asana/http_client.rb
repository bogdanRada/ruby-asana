require 'faraday'
require 'faraday_middleware'
require 'faraday_middleware/multi_json'

require_relative 'version'
require_relative 'http_client/error_handling'
require_relative 'http_client/response'

module Asana
  # Internal: Wrapper over Faraday that abstracts authentication, request
  # parsing and common options.
  class HttpClient
    # Internal: The default user agent to use in all requests to the API.
    USER_AGENT = "ruby-asana v#{Asana::VERSION}"

    # Internal: The API base URI.
    BASE_URI = 'https://app.asana.com/api/1.0'

    # Public: Initializes an HttpClient to make requests to the Asana API.
    #
    # authentication - [Asana::Authentication] An authentication strategy.
    # adapter        - [Symbol, Proc] A Faraday adapter, eiter a Symbol for
    #                  registered adapters or a Proc taking a builder for a
    #                  custom one. Defaults to Faraday.default_adapter.
    # user_agent     - [String] The user agent. Defaults to "ruby-asana vX.Y.Z".
    # config         - [Proc] An optional block that yields the Faraday builder
    #                  object for customization.
    def initialize(authentication:, adapter: nil, user_agent: nil, &config)
      @authentication = authentication
      @adapter        = adapter || Faraday.default_adapter
      @user_agent     = user_agent || USER_AGENT
      @config         = config
    end

    # Public: Performs a GET request against the API.
    #
    # resource_uri - [String] the resource URI relative to the base Asana API
    #                URL, e.g "/users/me".
    #
    # Returns an [Asana::HttpClient::Response] if everything went well.
    # Raises [Asana::Errors::APIError] if anything went wrong.
    def get(resource_uri, params: {})
      perform_request(:get, resource_uri, params)
    end

    private

    def connection
      Faraday.new do |builder|
        @authentication.configure(builder)
        builder.headers[:user_agent] = @user_agent
        configure_format(builder)
        add_middleware(builder)
        @config.call(builder) if @config
        use_adapter(builder, @adapter)
      end
    end

    def perform_request(method, resource_uri, body)
      handling_errors do
        url = BASE_URI + resource_uri
        Response.new(connection.public_send(method, url, body))
      end
    end

    def configure_format(builder)
      builder.request :multi_json
      builder.response :multi_json
    end

    def add_middleware(builder)
      builder.use Faraday::Response::RaiseError
      builder.use FaradayMiddleware::FollowRedirects
    end

    def use_adapter(builder, adapter)
      case adapter
      when Symbol
        builder.adapter(adapter)
      when Proc
        adapter.call(builder)
      end
    end

    def handling_errors(&request)
      ErrorHandling.handle(&request)
    end
  end
end
