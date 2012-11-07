require "ftw" # gem ftw
require "cabin" # gem cabin
require "thread"

ShutdownSignal = :shutdown

class Session
  def initialize
    @queue = Queue.new
    @recent = []
  end # def initialize

  def <<(chunk)
    @queue << chunk
    @recent << chunk
    @recent = @recent[0..100]
  end # def push

  def enumerator
    return Enumerator.new do |y|
      @recent.each { |chunk| y << chunk }
      while true
        chunk = @queue.pop
        break if chunk == ShutdownSignal
        y << chunk
      end
    end # Enumerator
  end # def enumerator

  def raw
    return Enumerator.new do |y|
      enumerator.each do |chunk|
        y << decode(chunk)
      end
    end # Enumerator
  end # def enumerator

  def decode(chunk)
    headersize = [1,1].pack("GN").size
    return chunk[headersize .. -1]
  end # def decode

  def close
    @queue << ShutdownSignal
  end
end # class Session

sessions = {}

port = ENV.include?("PORT") ? ENV["PORT"].to_i : 8888
server = FTW::WebServer.new("0.0.0.0", port) do |request, response|
  @logger = Cabin::Channel.get
  if request.path =~ /^\/s\//
    session = sessions[request.path] ||= Session.new
    if request.method == "POST"
      # TODO(sissel): Check if a session exists.

      begin
        request.read_http_body do |chunk|
          session << chunk
        end
      rescue EOFError
      end
      session.close
      sessions.delete(request.path)
    elsif request.method == "GET"
      response.status = 200
      response["Content-Type"] = "text/plain"
      if request["user-agent"] =~ /^curl\/[0-9]/
        # Curl. Send raw text.
        puts "curl request"
        response.body = session.raw
      else
        response.body = session.enumerator
      end
    else
      response.status = 400
      response.body = "Invalid method '#{request.method}'\n"
    end
  else
    response.status = 404
  end
end

Thread.abort_on_exception = true
server.run
