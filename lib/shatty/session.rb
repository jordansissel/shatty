require "thread"

module Shatty
  class Session
    def initialize
      @queue = Queue.new
      @recent = []
      @subscribers = []
      @subscriber_lock = Mutex.new

      @publisher_thread = Thread.new { run }
    end # def initialize

    def run
      while true
        chunk = @queue.pop
        puts "#{@subscribers.count} subscribers"
        @subscriber_lock.lock do
          @subscribers.each do |subscriber|
            subscriber << chunk
          end
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
      @subscriber_lock.lock do
        @subscribers << output
      end
    end # def subscribe

    def unsubscribe(output)
      @subscriber_lock.lock do
        @subscribers.delete(output)
      end
    end # def unsubscribe

    def self.decode(chunk)
      headersize = [1,1].pack("GN").size
      return chunk[headersize .. -1]
    end # def self.decode

    def close
      @queue << ShutdownSignal
    end
  end # class Session
end # module Shatty
