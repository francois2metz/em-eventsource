require "eventmachine"
require "em-http-request"

module EventMachine
  # EventSource
  # dev.w3.org/html5/eventsource/
  class EventSource
    # Get API url
    attr_reader :url
    # Get ready state
    attr_reader :ready_state
    # Ready state
    # The connection has not yet been established, or it was closed and the user agent is reconnecting.
    CONNECTING = 0
    # The user agent has an open connection and is dispatching events as it receives them.
    OPEN       = 1
    # The connection is not open, and the user agent is not trying to reconnect. Either there was a fatal error or the close() method was invoked.
    CLOSED     = 2
    # Create a new stream
    #
    # @param [String] url
    # @param [Hash] query
    # @param [Hash] headers
    def initialize(url, query={}, headers={})
      @url = url
      @query = query
      @headers = headers
      @ready_state = CLOSED

      @lastid = nil
      @retry = 3 # seconds

      @opens = []
      @errors = []
      @messages = []
      @on = {}
    end

    # Add open event handler
    def open(&block)
      @opens << block
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
      @ready_state = CONNECTING
      listen
    end

    # Cancel subscription
    def close
      @ready_state = CLOSED
      @req.close
    end

    protected

    def listen
      @req = prepare_request
      @req.errback do
        next if @ready_state == CLOSED
        @ready_state = CONNECTING
        @errors.each { |error| error.call("Connection lost. Reconnecting.") }
        EM.add_timer(@retry) do
          listen
        end
      end
      @req.headers do |headers|
        if headers.status != 200
          close
          @errors.each { |error| error.call("Unexpected response status #{headers.status}") }
          next
        end
        if /^text\/event-stream/.match headers['CONTENT_TYPE']
          @ready_state = OPEN
          @opens.each { |open| open.call }
        else
          close
          @errors.each { |error| error.call("The content-type '#{headers['CONTENT_TYPE']}' is not text/event-stream") }
        end
      end
      buffer = ""
      @req.stream do |chunk|
        buffer += chunk
        # TODO: manage \r, \r\n, \n
        while index = buffer.index("\n\n")
          stream = buffer.slice!(0..index)
          handle_stream(stream)
        end
      end
    end

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
        /^retry:(.+)$/.match(part) do |m|
          if m[1].strip! =~ /^[0-9]+$/
            @retry = m[1].to_i
          end
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
      headers = @headers.merge({'Cache-Control' => 'no-cache'})
      headers.merge!({'Last-Event-Id' => @lastid }) if not @lastid.nil?
      conn.get({ :query => @query,
                 :head  => headers})
      conn
    end
  end
end
