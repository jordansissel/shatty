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

def websocket(request, response, connection, session)
  require "base64" # stdlib 
  require "digest/sha1" # stdlib
  key = request["sec-websocket-key"]
  parser = FTW::WebSocket::Parser.new
  response.status = 101
  sec_accept = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  sec_accept_hash = Digest::SHA1.base64digest(sec_accept)
  response["Upgrade"] = "websocket"
  response["Connection"] = "Upgrade"
  response["Sec-WebSocket-Accept"] = sec_accept_hash
  puts "WEBSOCKET; #{connection}"
end # def websocket

def raw(request, response, session)
  response.status = 200
  response["Content-Type"] = "text/plain"
  queue = Queue.new
  session.subscribe(queue)

  # Curl or wget. Send raw text.
  response.body = Enumerator.new do |y|
    while true
      chunk = queue.pop
      break if chunk == ShutdownSignal
      puts "Raw: #{chunk.inspect}"
      y << Session.decode(chunk)
    end # while true
  end # response.body
end # def raw

def servesession(request, response, session)
  response.status = 200
  response["Content-Type"] = "text/plain"
  queue = Queue.new
  session.subscribe(queue)

  # Curl or wget. Send raw text.
  response.body = Enumerator.new do |y|
    while true
      chunk = queue.pop
      break if chunk == ShutdownSignal
      y << chunk
    end # while true
  end # response.body
end # def raw

sessions = {}

port = ENV.include?("PORT") ? ENV["PORT"].to_i : 8888
server = FTW::WebServer.new("0.0.0.0", port) do |request, response, connection|
  logger = Cabin::Channel.get
  logger.level = :debug
  logger.subscribe(STDOUT)
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
        puts request["connection"]
        if request["connection"].split(/,\s*/).include?("Upgrade") && request["upgrade"] == "websocket"
          logger.info("websocket")
          websocket(request, response, connection, session)
        else
          if request["user-agent"] =~ /^(curl|Wget)/
            raw(request, response, session)
          else # not curl/wget
            servesession(request, response, session)
          end # user agent
        end # not websocket
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
