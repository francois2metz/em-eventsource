# EventSource client for EventMachine

source = EM::EventSource.new ("/live/meeting", {:start => 0})

source.message do |message|
end

source.error do |error|
end

source.on "plop" do |message|
end

source.start
source.close
