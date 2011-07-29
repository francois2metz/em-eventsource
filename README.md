# EventSource client for EventMachine

This is currently a work in progress.

See the specification: http://dev.w3.org/html5/eventsource/

# How to use it

Install with Rubygems:

    gem install em-eventsource

If you use bundler, add it to your Gemfile:

    gem "em-ucengine", "~>0.0.1"

Then, you can use it in your code:

    require "em-eventsource"

    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")

      source.open do
          puts "opened"
      end

      source.message do |message|
        puts "new message #{message}"
      end

      source.on "eventname" do |message|
        puts "eventname #{message}"
      end

      source.error do |error|
        puts "error #{error}"
      end

      source.start # Start listening
      #source.close
    end

# Credits

Copyright (c) 2011 af83
