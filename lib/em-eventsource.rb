require "eventmachine"
require "em-http-request"

module EventMachine
  class EventSource
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

    def on(type, &block)
      @on[type] = [] if @on[type].nil?
      @on[type] << block
    end

    def message(&block)
      @messages << block
    end

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
