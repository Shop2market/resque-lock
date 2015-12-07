#require 'resque/status'
#require 'resque/lock'
require "cgi"

module Resque
  module LockServer
    
    VIEW_PATH = File.join(File.dirname(__FILE__), 'lock_server', 'views')
    
    def self.registered(app)
    
      app.get '/locks' do
        @start = params[:start].to_i
        @end = @start + ( params[:per_page] || 50 )
        @locks = Resque.redis.keys("lock:*") + Resque.redis.keys("competitive-lock:*")
        lock_view(:locks)
      end
      
      app.helpers do
        def lock_view(filename, options = {}, locals = {})
          erb(File.read(File.join(::Resque::LockServer::VIEW_PATH, "#{filename}.erb")), options, locals)
        end
      end
      
      app.post '/locks/:id/kill' do
        Resque.redis.del( params[:id] )
        redirect u(:statuses)
      end
      
      app.post '/locks/clear' do
        Resque.redis.keys("lock:*").each{|k| Resque.redis.del( k ) }
        redirect u(:locks)
      end
      
      
      app.tabs << "Locks"
    end

  end
end
Resque::Server.register Resque::LockServer
