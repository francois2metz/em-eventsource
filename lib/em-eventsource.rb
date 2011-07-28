require "eventmachine"
require "em-http-request"

module EventMachine
  # EventSource
  # dev.w3.org/html5/eventsource/
  class EventSource
    # Create a new stream
    #
    # @param [String] url
    # @param [Hash] query
    # @param [Hash] headers
    def initialize(url, query={}, headers={})
      @url = url
      @query = query
      @headers = headers

      @closed = false
      @lastid = nil
      @retry = 3 # seconds

      @errors = []
      @messages = []
      @on = {}
    end

    # Add a specific event handler
    #
    # @param [String] name of event
    def on(name, &block)
      @on[name] = [] if @on[name].nil?
      @on[name] << block
    end

    # Add message event handler
    def message(&block)
      @messages << block
    end

    # Add error event handler
    def error(&block)
      @errors << block
    end

    # Start subscription
    def start
      @closed = false
      listen
    end

    # Cancel subscription
    def close
      @closed = true
      @req.close
    end

    protected

    def listen
      @req = prepare_request
      @req.errback do
        next if @canceled
        EM.add_timer(@retry) do
          listen
        end
      end
      @req.headers do |headers|
        p headers
      end
      stream = ""
      @req.stream do |chunk|
        stream += chunk
        while index = stream.index("\n")
          subpart = stream[0..index]
          /^data: (.+)$/.match(subpart) do |m|
            @messages.each { |message| message.call(m[1]) }
          end
          /^id: (.+)$/.match(subpart) do |m|
            @lastid = m[1]
          end
          # TODO: handle retry
          # TODO: handle event
          # TODO: multiline data
          stream = stream[(index + 1)..stream.length]
        end
      end
    end

    def prepare_request
      conn = EM::HttpRequest.new(@url)
      conn.get({ :query => @query,
                 :head  => {'Last-Event-Id' => @lastid }.merge(@headers)})
      conn
    end
  end
end
