# EventSource client for EventMachine

This is currently a work in progress.

See the specification: http://dev.w3.org/html5/eventsource/

## Install

Install with Rubygems:

    gem install em-eventsource

If you use bundler, add it to your Gemfile:

    gem "em-ucengine", "~>0.1.0"

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

## Licence

MIT License

Copyright (C) 2011 by af83

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
