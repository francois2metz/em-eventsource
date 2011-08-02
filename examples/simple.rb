$: << 'lib' << '../lib'

require 'em-eventsource'

EM.run do
  source = EM::EventSource.new("http://googlecodesamples.com/html5/sse/sse.php")

  source.message do |message|
    puts "new message #{message}"
  end

  source.error do |error|
    puts "error #{error}"
  end

  source.start
end
