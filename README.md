# EventSource client for EventMachine

This is currently a work in progress.

See the specification: http://dev.w3.org/html5/eventsource/

## Install

Install with Rubygems:

    gem install em-eventsource

If you use bundler, add it to your Gemfile:

    gem "em-ucengine", "~>0.0.1"

## Usage

Basic usage:

    require "em-eventsource"
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")
      source.message do |message|
        puts "new message #{message}"
      end
      source.start # Start listening
    end

Listening specific event name:

    source.on "eventname" do |message|
      puts "eventname #{message}"
    end

Handle error:

    source.error do |error|
      puts "error #{error}"
    end

Handle open stream:

    source.open do
      puts "opened"
    end

Close the stream:

    source.close

Current status of the connection:

    source.ready_state # Can be EM::EventSource::CLOSED, EM::EventSource::CONNECTING, EM::EventSource::OPEN

Override the default retry value (if the connection is lost):

    source.retry = 5 # in seconds

Get Last-Event-Id value:

    source.last_event_id

Attach middleware:

    source.use EM::Middleware::JSONResponse

## Credits

Copyright (c) 2011 af83
