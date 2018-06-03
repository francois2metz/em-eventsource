require "em-eventsource"

module EventMachine
  class MockHttpRequest
    attr_reader :url, :get_args, :middlewares, :opts, :response_header, :closed

    def initialize(url, opts={})
      @url = url
      @streams = []
      @errors = []
      @callbacks = []
      @headers = []
      @middlewares = []
      @opts = opts
      @response_header = HttpResponseHeader.new({})
      @closed = false
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

    def callback(&block)
      @callbacks << block
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

    def call_callback
      @callbacks.each { |callback| callback.call("chunk of data") }
    end

    def call_headers(headers)
      @response_header = headers
      @headers.each { |header| header.call(headers) }
    end

    def close(reason="")
      @closed = true
    end
  end

  class HttpRequest
    def self.new(url, opts={})
      EM::MockHttpRequest.new(url, opts)
    end
  end
end
