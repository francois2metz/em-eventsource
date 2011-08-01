#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "minitest/autorun"

describe EventMachine::EventSource do

  def start_source(url="http://example.com/streaming", query={}, headers={})
    EM.run do
      source = EventMachine::EventSource.new(url, query, headers)
      source.start
      req = source.instance_variable_get "@req"
      yield source, req if block_given?
    end
  end

  def create_response_headers(status, content_type="", other={})
    headers = EM::HttpResponseHeader.new
    headers.http_status = status
    headers['CONTENT_TYPE'] = content_type
    headers.merge!(other)
  end

  it "connect to the good server" do
    start_source do |source, req|
      source.ready_state.must_equal EM::EventSource::CONNECTING
      source.url.must_be :==, "http://example.com/streaming"
      req.url.must_be :==, "http://example.com/streaming"
      req.get_args[0].must_be :==, { :query => {},
                                     :head  => {"Cache-Control" => "no-cache"} }
      EM.stop
    end
  end

  it "connect to the good server with query and headers" do
    start_source "http://example.net/streaming", {:chuck => "norris"}, {"DNT" => 1} do |source, req|
      req.url.must_be :==, "http://example.net/streaming"
      req.get_args[0].must_be :==, { :query => {:chuck => "norris"},
                                     :head  => {"DNT" => 1, "Cache-Control" => "no-cache"} }
      EM.stop
    end
  end

  it "connect and error if status != 200" do
    start_source do |source, req|
      source.error do |error|
        error.must_equal "Unexpected response status 400"
        source.ready_state.must_equal EM::EventSource::CLOSED
        EM.stop
      end
      source.open { assert false }
      req.call_headers(create_response_headers "400")
    end
  end

  it "connect and error if the content-type doens't match text/event-stream" do
    start_source do |source, req|
      source.error do |error|
        error.must_equal "The content-type 'text/plop' is not text/event-stream"
        source.ready_state.must_equal EM::EventSource::CLOSED
        EM.stop
      end
      req.call_headers(create_response_headers "200", "text/plop")
    end
  end

  it "connect and error if the content-type is not set" do
    start_source do |source, req|
      source.error do |error|
        error.must_equal "The content-type '' is not text/event-stream"
        EM.stop
      end
      req.call_headers(create_response_headers "200", "", "HEADER_NAME" => "BAD")
    end
  end

 it "connect without error with 200 and good content-type" do
    start_source do |source, req|
      source.start
      source.error do
        assert false
      end
      source.open do
        source.ready_state.must_equal EM::EventSource::OPEN
        assert true
        EM.stop
      end
      req.call_headers(create_response_headers "200", "text/event-stream; charset=utf-8")
    end
  end

  it "connect and handle message" do
    start_source do |source, req|
      source.message do |message|
        message.must_be :==, "hello world"
        source.close
        EM.stop
      end
      req.stream_data("data: hello world\n\n")
    end
  end

  it "handle multiple messages" do
    start_source do |source, req|
      source.message do |message|
        message.must_be :==, "hello world\nplop"
        source.close
        EM.stop
      end
      req.stream_data("data: hello world\ndata:plop\n\n")
    end
  end

  it "handle event name" do
    start_source do |source, req|
      source.on "plop" do |message|
        message.must_be :==, "hello world"
        source.close
        EM.stop
      end
      req.stream_data("data: hello world\nevent:plop\n\n")
    end
  end

  it "reconnect after error with last-event-id" do
    start_source do |source, req|
      req.stream_data("id: roger\n\n")
      source.error do |error|
        error.must_equal "Connection lost. Reconnecting."
        source.ready_state.must_equal EM::EventSource::CONNECTING
        EM.add_timer(4) do
          req2 = source.instance_variable_get "@req"
          refute_same(req2, req)
          source.last_event_id.must_be :==, "roger"
          req2.get_args[0].must_be :==, { :head  => { "Last-Event-Id" => "roger",
                                                      "Cache-Control" => "no-cache" },
                                          :query => {} }
          EM.stop
        end
      end
      req.call_errback
    end
  end

  it "handle retry event" do
    start_source do |source ,req|
      req.stream_data("retry: plop\n\n")
      source.retry.must_be :==, 3
      req.stream_data("retry: 45plop\n\n")
      source.retry.must_be :==, 3
      req.stream_data("retry: 45\n\n")
      source.retry.must_be :==, 45
      EM.stop
    end
  end

end
