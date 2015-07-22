#!/usr/bin/env ruby
# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require "minitest/autorun"
require "minitest-spec-context"

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
      source.url.must_equal "http://example.com/streaming"
      req.url.must_equal "http://example.com/streaming"
      req.opts[:inactivity_timeout].must_equal 60
      req.get_args[0].must_equal({ :query => {},
                                   :head  => {"Cache-Control" => "no-cache",
                                              "Accept" => "text/event-stream"} })
      EM.stop
    end
  end

  it "connect to the good server with query and headers" do
    start_source "http://example.net/streaming", {:chuck => "norris"}, {"DNT" => 1} do |source, req|
      req.url.must_equal "http://example.net/streaming"
      req.get_args[0].must_equal({ :query => {:chuck => "norris"},
                                   :head  => {"DNT" => 1,
                                              "Cache-Control" => "no-cache",
                                              "Accept" => "text/event-stream"} })
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

  {"LF" => "\n", "CRLF" => "\r\n"}.each do |eol_desc, eol|
    context "with #{eol_desc} EOL" do
      it "connect and handle message" do
        start_source do |source, req|
          source.message do |message|
            message.must_equal "hello world"
            source.close
            EM.stop
          end
          req.stream_data("data: hello world#{eol}#{eol}")
        end
      end

      it "handle multiple messages" do
        start_source do |source, req|
          source.message do |message|
            message.must_equal "hello world\nplop"
            source.close
            EM.stop
          end
          req.stream_data("data: hello world#{eol}data:plop#{eol}#{eol}")
        end
      end

      it "ignore empty message" do
        start_source do |source, req|
          source.message do |message|
            message.must_equal "hello world"
            EM.stop
          end
          req.stream_data(":#{eol}#{eol}")
          req.stream_data("data: hello world#{eol}#{eol}")
        end
      end

      it "handle event name" do
        start_source do |source, req|
          source.on "plop" do |message|
            message.must_equal "hello world"
            source.close
            EM.stop
          end
          req.stream_data("data: hello world#{eol}event:plop#{eol}#{eol}")
        end
      end

      it "reconnect after error with last-event-id" do
        start_source do |source, req|
          req.stream_data("id: roger#{eol}#{eol}")
          source.error do |error|
            error.must_equal "Connection lost. Reconnecting."
            source.ready_state.must_equal EM::EventSource::CONNECTING
            EM.add_timer(4) do
              req2 = source.instance_variable_get "@req"
              refute_same(req2, req)
              source.last_event_id.must_equal "roger"
              req2.get_args[0].must_equal({ :head => { "Last-Event-Id" => "roger",
                                                       "Accept" => "text/event-stream",
                                                       "Cache-Control" => "no-cache" },
                                            :query => {} })
              EM.stop
            end
          end
          req.call_errback
        end
      end

      it "reconnect after callback with last-event-id" do
        start_source do |source, req|
          req.stream_data("id: roger#{eol}#{eol}")
          source.error do |error|
            error.must_equal "Connection lost. Reconnecting."
            source.ready_state.must_equal EM::EventSource::CONNECTING
            EM.add_timer(4) do
              req2 = source.instance_variable_get "@req"
              refute_same(req2, req)
              source.last_event_id.must_equal "roger"
              req2.get_args[0].must_equal({ :head => { "Last-Event-Id" => "roger",
                                                       "Accept" => "text/event-stream",
                                                       "Cache-Control" => "no-cache" },
                                            :query => {} })
              EM.stop
            end
          end
          req.call_callback
        end
      end

      it "handle retry event" do
        start_source do |source ,req|
          req.stream_data("retry: plop#{eol}#{eol}")
          source.retry.must_equal 3
          req.stream_data("retry: 45plop#{eol}#{eol}")
          source.retry.must_equal 3
          req.stream_data("retry: 45#{eol}#{eol}")
          source.retry.must_equal 45
          EM.stop
        end
      end
    end
  end

  it "add connection middlewares" do
    start_source do |source ,req|
      proc = Proc.new {}
      source.use "oup", "la", "boom", &proc
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["oup", "la", "boom", proc]]
      EM.stop
    end

    start_source do |source ,req|
      proc = Proc.new {}
      source.use "oup", &proc
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["oup", proc]]
      EM.stop
    end

    start_source do |source ,req|
      proc = Proc.new {}
      source.use "oup", nil, nil, &proc
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["oup", nil, nil, proc]]
      EM.stop
    end

    start_source do |source ,req|
      source.use "oup"
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["oup", nil]]
      EM.stop
    end

    start_source do |source ,req|
      source.use "oup", "la", "boom"
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["oup", "la", "boom", nil]]
      EM.stop
    end

    start_source do |source ,req|
      source.use("oup", "la", "boom") do
        true
      end
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.size.must_equal 1
      req2.middlewares[0].size.must_equal 4
      req2.middlewares[0][0..2].must_equal ["oup", "la", "boom"]
      req2.middlewares[0][3].class.must_equal Proc
      EM.stop
    end
  end

  it "keeps connection middlewares calls the same" do
    start_source do |source ,req|
      source.use "Keep", "me", "equal"
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["Keep", "me", "equal", nil]]
      source.close
      source.start
      req2 = source.instance_variable_get "@req"
      req2.middlewares.must_equal [["Keep", "me", "equal", nil]]
      EM.stop
    end
  end

  it "allows to set the inactivity_timeout" do
    EM.run do
      source = EventMachine::EventSource.new("")
      source.inactivity_timeout = 0
      source.start
      req = source.instance_variable_get "@req"
      req.opts[:inactivity_timeout].must_equal 0
      EM.stop
    end
  end

  it "doesn't fail when trying to close not yet started source" do
    EventMachine::EventSource.new("").close
  end

end
