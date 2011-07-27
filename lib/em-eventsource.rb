module EventMachine
  class EventSource
    def initialize(url, query={}, headers={})
      @Url = url
      @query = query
      @headers = headers

      @closed = false
      @lastid = nil
      @retry = 3 # seconds
    end

    def on(type, &block)

    end

    def message(&block)

    end

    def error(&block)

    end

    def listen
      @req = prepare_request(:get, @url,
                             { :query => @query,
                               :head  => {'Last-Event-Id' => @lastid }.merge(@headers)})
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
            @block.call(m[1])
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
  end
end
