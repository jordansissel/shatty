require "ftw" # gem ftw
require "cabin" # gem cabin
require "thread"

Thread.abort_on_exception = true
ShutdownSignal = :shutdown

class Session
  def initialize
    @queue = Queue.new
    @recent = []
    @subscribers = []

    @publisher_thread = Thread.new { run }
  end # def initialize

  def run
    while true
      chunk = @queue.pop
      puts "#{@subscribers.count} subscribers"
      @subscribers.each do |subscriber|
        #p subscriber => chunk
        subscriber << chunk
      end
      break if chunk == ShutdownSignal
    end
  end # def run

  def <<(chunk)
    @recent << chunk
    @recent = @recent[0..100]
    @queue << chunk
  end # def <<

  def subscribe(output)
    @recent.each { |c| output << c }
    @subscribers << output
  end # def subscribe

  def unsubscribe(output)
    @subscribers.delete(output)
  end # def unsubscribe

  def self.decode(chunk)
    headersize = [1,1].pack("GN").size
    return chunk[headersize .. -1]
  end # def self.decode

  def close
    @queue << ShutdownSignal
  end
end # class Session

sessions = {}

port = ENV.include?("PORT") ? ENV["PORT"].to_i : 8888
server = FTW::WebServer.new("0.0.0.0", port) do |request, response|
  @logger = Cabin::Channel.get
  case request.path
    when /^\/s\//
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
        puts request
        response.status = 200
        response["Content-Type"] = "text/plain"
        queue = Queue.new
        session.subscribe(queue)
        if request["user-agent"] =~ /^(curl|Wget)/
          # Curl or wget. Send raw text.
          response.body = Enumerator.new do |y|
            while true
              chunk = queue.pop
              break if chunk == ShutdownSignal
              puts "Raw: #{chunk.inspect}"
              y << Session.decode(chunk)
            end
          end
        else
          response.body = Enumerator.new do |y|
            while true
              chunk = queue.pop
              break if chunk == ShutdownSignal
              puts "Plain: #{chunk.inspect}"
              y << chunk
            end
          end
        end
      else
        response.status = 400
        response.body = "Invalid method '#{request.method}'\n"
      end
    # end when /^\/s\/
    else
      response.status = 404
      response.body = "No such file: #{request.path}"
  end # end case request.path
end # FTW::WebServer.new do ...

Thread.abort_on_exception = true
server.run
