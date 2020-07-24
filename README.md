# EventSource client for EventMachine

See the specification: https://html.spec.whatwg.org/multipage/server-sent-events.html

## Install

Install with Rubygems:

    gem install em-eventsource

If you use bundler, add it to your Gemfile:

    gem "em-eventsource", "~> 0.3.0"

## Usage

Basic usage:

```ruby
require "em-eventsource"
EM.run do
  source = EventMachine::EventSource.new("http://example.com/streaming")
  source.message do |message|
    puts "new message #{message}"
  end
  source.start # Start listening
end
```

Listening specific event name:

```ruby
source.on "eventname" do |message|
  puts "eventname #{message}"
end
```

Handle error:

```ruby
source.error do |error|
  puts "error #{error}"
end
```

Handle open stream:

```ruby
source.open do
  puts "opened"
end
```

Close the stream:

```ruby
source.close
```

Current status of the connection:

```ruby
# Can be:
# - EM::EventSource::CLOSED
# - EM::EventSource::CONNECTING
# - EM::EventSource::OPEN
source.ready_state
```

Override the default retry value (if the connection is lost):

```ruby
source.retry = 5 # in seconds (default 3)
```

Get Last-Event-Id value:

```ruby
source.last_event_id
```

Attach middleware:

```ruby
source.use EM::Middleware::JSONResponse
```

Set the inactivity timeout. Set to 0 to disable the timeout.

```ruby
source.inactivity_timeout = 120 # in seconds (default: 60).
```

## Licence

MIT License

Copyright (C) 2020 François de Metz

Copyright (C) 2011 af83
