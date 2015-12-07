require 'resque'
require 'uuid'

module Resque
  module Lock

    # normal lock
    def lock_key( opts = {} )
      options = opts.dup
      klass = options.delete("klass") || self.name
      "lock:#{klass}-#{options.to_a.sort{|a,b| a[0].to_s <=> b[0].to_s }.map{|a| a.join("=") }.join("|")}"
    end

    def competitive_lock_key( options = {} )
      "competitive-#{lock_key( options.dup )}"
    end

    def locked?( options )
      Resque.redis.exists( lock_key( options ) )
    end

    def lock_uuid( options )
      Resque.redis.get( lock_key( options ) )
    end

    # competitive lock
    def _extra_locks_list_options options = {}
      if self.respond_to? :extra_locks_list_options
        begin
          self.send :extra_locks_list_options, options
        rescue
          []
        end
      else
        []
      end
    end

    def _extra_locks_jobs_list_options options = {}
      if self.respond_to? :extra_locks_jobs_list_options
        begin
          self.send :extra_locks_jobs_list_options, options
        rescue
        end
      else
        []
      end
    end

    def locked_by_competitor? options
      Resque.redis.exists( competitive_lock_key( options ) )
    end

    def with_competitive_lock uuid, options
      _extra_locks_list_options( options ).each do | extra_lock_opts |
        competitive_lock( extra_lock_opts )
      end
      _extra_locks_jobs_list_options( options ).each do | extra_lock_jobs_opts |
        competitive_lock( extra_lock_jobs_opts )
      end
      begin
        yield
      ensure
        _extra_locks_jobs_list_options( options ).each do | extra_lock_jobs_opts |
          competitive_unlock( extra_lock_jobs_opts )
        end
        _extra_locks_list_options( options ).each do | extra_lock_opts |
          competitive_unlock( extra_lock_opts )
        end
      end
    end

    # Where the magic happens.
    def enqueue(klass, options = {})
      # Abort if another job added.
      uuid = lock_uuid( options )
      if uuid.nil? || uuid.empty?
        uuid = super(klass, options)
        Resque.redis.set( lock_key( options ), uuid ) unless Resque.inline
      end
      uuid
    end

    def around_perform_lock *args
      unless locked_by_competitor? args[1]
        uuid = lock_uuid( args[1] )
        begin
          with_competitive_lock uuid, args[1] do
            yield
          end
        rescue => e
          unlock( args[1] )
          raise e
        end
        unlock( args[1] )
      else
        Resque.enqueue(self, *args)
      end
    end
    def competitive_lock_value( options )
      Resque.redis.get( competitive_lock_key( options ) ).to_i
    end
  protected
    def competitive_lock( options )
      Resque.redis.set( competitive_lock_key( options ),
        Resque.redis.get( competitive_lock_key( options ) ).to_i + 1 )
    end
    def competitive_unlock( options )
      lock = Resque.redis.get( competitive_lock_key( options ) )
      unless lock.nil?
        if lock.to_i <= 1
          Resque.redis.del( competitive_lock_key( options ) )
        else
          Resque.redis.set( competitive_lock_key( options ),
            Resque.redis.get( competitive_lock_key( options ) ).to_i - 1 )
        end
      end
    end
    def unlock( options )
      Resque.redis.del( lock_key( options ) )
    end

  end
end
