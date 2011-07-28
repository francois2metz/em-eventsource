require "em-eventsource"

module EventMachine
  class MockHttpRequest
    attr_reader :url, :get_args

    def initialize(url)
      @url = url
      @streams = []
      @errors = []
      @headers = []
    end

    def get(*args)
      @get_args = args
    end

    def stream(&block)
      @streams << block
    end

    def errback(&block)
      @errors << block
    end

    def headers(&block)
      @headers << block
    end

    def stream_data(data)
      @streams.each { |stream| stream.call(data) }
    end

    def close

    end
  end

  class HttpRequest
    def self.new(url)
      EM::MockHttpRequest.new(url)
    end
  end
end
