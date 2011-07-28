#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "minitest/autorun"

describe EventMachine::EventSource do
  it "connect to the good server" do
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming", {:chuck => "norris"}, {"DNT" => 1})
      source.start
      req = source.instance_variable_get "@req"
      req.url.must_be :==, "http://example.com/streaming"
      req.get_args[0].must_be :==, { :query => { :chuck => "norris"},
                                     :head  => { "Last-Event-Id" => nil, "DNT" => 1} }
      EM.stop
    end
  end

  it "connect and handle message" do
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")
      source.message do |message|
        message.must_be :==, "hello world"
        source.close
        EM.stop
      end
      source.start
      req = source.instance_variable_get "@req"
      req.stream_data("data: hello world\n\n")
    end
  end

  it "handle multiple messages" do
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")
      source.message do |message|
        message.must_be :==, "hello world\nplop"
        source.close
        EM.stop
      end
      source.start
      req = source.instance_variable_get "@req"
      req.stream_data("data: hello world\ndata:plop\n\n")
    end
  end

  it "handle event name" do
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")
      source.on "plop" do |message|
        message.must_be :==, "hello world"
        source.close
        EM.stop
      end
      source.start
      req = source.instance_variable_get "@req"
      req.stream_data("data: hello world\nevent:plop\n\n")
    end
  end

  it "reconnect after error" do
    EM.run do
      source = EventMachine::EventSource.new("http://example.com/streaming")
      source.start
      req = source.instance_variable_get "@req"
      req.call_errback
      EM.add_timer(4) do
        req2 = source.instance_variable_get "@req"
        refute_same(req2, req)
        EM.stop
      end
    end
  end

end
