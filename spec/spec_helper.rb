require "em-eventsource"

module EventMachine
  class MockHttpRequest
    attr_reader :url, :get_args, :middlewares, :opts

    def initialize(url, opts={})
      @url = url
      @streams = []
      @errors = []
      @headers = []
      @middlewares = []
      @opts = opts
    end

    def get(*args)
      @get_args = args
      self
    end

    def stream(&block)
      @streams << block
    end

    def errback(&block)
      @errors << block
    end

    def use(*args, &block)
      @middlewares << [*args, block]
    end

    def headers(&block)
      @headers << block
    end

    def stream_data(data)
      @streams.each { |stream| stream.call(data) }
    end

    def call_errback
      @errors.each { |error| error.call() }
    end

    def call_headers(headers)
      @headers.each { |header| header.call(headers) }
    end

    def close(reason)
      # do nothing
    end
  end

  class HttpRequest
    def self.new(url, opts={})
      EM::MockHttpRequest.new(url, opts)
    end
  end
end
