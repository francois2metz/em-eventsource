#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "minitest/autorun"

describe EventMachine::EventSource do
  it "connect and handle message" do
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")
      source.message do |message|
        message.must_be :==, 'hello world'
        source.close
        EM.stop
      end
      EM.add_timer(1) do
        req = source.instance_variable_get "@req"
        req.stream_data("data: hello world\n")
      end
      source.start
    end
  end
end
