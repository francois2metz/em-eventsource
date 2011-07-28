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
        @errors.each { |error| error.call() }
        EM.add_timer(@retry) do
          listen
        end
      end
      # TODO: manage content-type
      @req.headers do |headers|
        p headers
      end
      stream = ""
      @req.stream do |chunk|
        stream += chunk
        # TODO: manage \r, \r\n, \n
        while index = stream.index("\n\n")
          subpart = stream[0..index]
          handle_stream(subpart)
          stream = stream[(index + 1)..stream.length]
        end
      end
    end

    # TODO: handle retry
    def handle_stream(stream)
      event = []
      name = nil
      stream.split("\n").each do |part|
        /^data:(.+)$/.match(part) do |m|
          event << m[1].strip
        end
        /^id:(.+)$/.match(part) do |m|
          @lastid = m[1].strip
        end
        /^event:(.+)$/.match(part) do |m|
          name = m[1].strip
        end
      end
      if name.nil?
        @messages.each { |message| message.call(event.join("\n")) }
      else
        @on[name].each { |message| message.call(event.join("\n")) } if not @on[name].nil?
      end
    end

    def prepare_request
      conn = EM::HttpRequest.new(@url)
      # TODO: add Cache-Control: no-cache
      conn.get({ :query => @query,
                 :head  => {'Last-Event-Id' => @lastid }.merge(@headers)})
      conn
    end
  end
end
