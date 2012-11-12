require "ftw" # gem ftw
require "rack/handler/ftw" # gem ftw
require "thread" # stdlib
require "shatty/session"
require "sinatra/base"

Thread.abort_on_exception = true

module Shatty
  class Server < Sinatra::Base
    def initialize
      @sessions = {}
      @sessions_lock = Mutex.new
      super
    end # def initialize

    helpers do
      def id(*args) 
        return params["splat"]
      end

      def session(*args)
        @sessions_lock.lock do
          @sessions[id] ||= Session.new
          return @sessions[id]
        end
      end # def session
    end # helpers

    set(:show_exceptions, false)
    set(:websocket) do |value| 
      condition do
        value == (env["HTTP_CONNECTION"].split(/,\s*/).include?("Upgrade") \
                  && env["HTTP_UPGRADE"] == "websocket")
      end # condition
    end # set :websocket

    get "/s/*", :agent => /^(curl|Wget)/ do
      # send raw
    end # get /s/* for curl/wget clients

    get "/s/*", :websocket => true do
      ws = FTW::WebSocket::Rack.new(env)
      stream(:keep_open) do |out|
        #ws.each do |payload|
          #ws.publish(payload)
        #end
        class << ws
          def <<(payload)
            publish(payload)
          end
        end
        session.subscribe(ws)
      end

      # Send code 101 and the rest of the websocket response.
      ws.rack_response
    end # get /s/* for websocket clients

    get "/s/*" do
      # send html interface?
    end # get /s/* for everyone else
 
    post "/s/*" do
      puts "POST"
      begin
        s = session
        #while true
          #data = request.body.read(16384)
          #puts data
          #session << data
        #end
      rescue => e
        puts "exception" => e
      end
      [ 503, {}, "Something bad happened?" ]
      # If this 'id' session doesn't exist
      #   Create a new session
      # else
      #   Say 409 Conflict
      #[409, {}, "This session (#{id}) is already in use by a terminal. Choose another identifier."]
    end
  end
end

if __FILE__ == $0
  require "cabin"
  logger = Cabin::Channel.get
  logger.subscribe(STDOUT)
  logger.level = :info
  Rack::Handler::FTW.run(Shatty::Server.new, :Host => "0.0.0.0", :Port => 8080)
end
