require "ftw" # gem ftw
require "cabin" # gem cabin
require "thread"

queue = Queue.new
recent = []

server = FTW::WebServer.new("0.0.0.0", ENV["PORT"].to_i || 8888) do |request, response|
  @logger = Cabin::Channel.get
  if request.method == "POST" and request.path == "/share/live/example"
    response.status = 200
    request.read_http_body do |chunk|
      queue.push(chunk)
      recent.push(chunk)
      recent = recent[0..100]
    end
  elsif request.method == "GET" and request.path == "/share/live/example"
    response.status = 200
    enumerator = Enumerator.new do |y| 
      recent.each { |chunk| y << chunk }
      y << queue.pop while true
    end
    response.body = enumerator
  else
    response.status = 404
  end
end

server.run
