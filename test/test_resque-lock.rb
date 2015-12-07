require 'test_helper'

class TestLockedJob
  include Resque::Plugins::Status
  extend Resque::Lock
  @queue = :test

  def perform
  end
end

$release_worker = false

class TestExtraLockedJob
  include Resque::Plugins::Status
  extend Resque::Lock
  @queue = :test

  def self.extra_locks_list_options options
    [{ "arrg2" => 1 }]
  end

  def self.extra_locks_jobs_list_options options
    [
      { "klass" => "TestLockedJob", "arrg1" => 1 },
      { "klass" => "TestLockedJob", "arrg2" => 1 },
    ]
  end

  def perform
    while !$release_worker
      sleep 1
    end
  end
end


class TestResqueLock < Minitest::Test

  describe "Resque::Lock" do
    before do
      Resque.redis.flushall
    end
    describe "on enqueue with extra lock" do
      before do
        @options = { :arrg1 => 1 }
        @uuid    = TestExtraLockedJob.create(@options)
        @status  = Resque::Plugins::Status::Hash.get( @uuid )
        $release_worker = false
      end
      it "create extra locks during job running" do
        worker = Resque::Worker.new(TestExtraLockedJob.instance_eval{@queue})
        worker_thread = Thread.new { worker.process }
        sleep 1
        assert TestExtraLockedJob.locked?( :arrg1 => 1 )
        assert TestExtraLockedJob.locked_by_competitor?( :arrg2 => 1 )
        assert TestLockedJob.locked_by_competitor?( :arrg1 => 1 )
        assert TestLockedJob.locked_by_competitor?( :arrg2 => 1 )
        assert_equal 1, TestLockedJob.competitive_lock_value( :arrg2 => 1 )
        assert_equal 1, TestLockedJob.competitive_lock_value( :arrg1 => 1 )
        assert !TestLockedJob.locked?( :arrg1 => 1 )
        TestLockedJob.create( :arrg1 => 2 )
        assert TestLockedJob.locked?( :arrg1 => 2 )

        TestExtraLockedJob.create({ :arrg2 => 1 })

        assert 2, TestLockedJob.competitive_lock_value( :arrg2 => 1 )
        assert 2, TestLockedJob.competitive_lock_value( :arrg1 => 1 )

        $release_worker = true
        worker_thread.join
        assert !TestLockedJob.locked?( :arrg1 => 1 )
        assert TestLockedJob.locked?( :arrg1 => 2 )
        assert 0, TestLockedJob.competitive_lock_value( :arrg2 => 1 )
        assert 0, TestLockedJob.competitive_lock_value( :arrg1 => 1 )
        assert 0, TestExtraLockedJob.competitive_lock_value( :arrg1 => 1 )
        assert 0, TestExtraLockedJob.competitive_lock_value( :arrg2 => 1 )
      end
    end
    describe "on enqueue" do
      before do
        @options = { :arrg1 => 1 }
        @uuid    = TestLockedJob.create(@options)
        @status  = Resque::Plugins::Status::Hash.get( @uuid )
      end
      it "create a lock with appropriated status uuid" do
        assert TestLockedJob.locked?( @options )
        assert !TestExtraLockedJob.locked?( @options )
        assert @status["status"] == "queued"
      end
      describe "and enqueue" do
        before do
          @uuid2   = TestLockedJob.create(@options)
          @status2 = Resque::Plugins::Status::Hash.get( @uuid2 )
        end
        it "be locked with the same job id" do
          assert TestLockedJob.locked?( @options )
          assert !TestExtraLockedJob.locked?( @options )
          assert @status2["status"] == "queued"
          assert_equal @status, @status2
          assert @uuid == @uuid2
        end
      end
    end
    describe 'on inline' do
      before do
        @options = { :arrg1 => 1 }
        Resque.inline = true
        $release_worker = true
        @uuid    = TestLockedJob.create(@options)
        @status  = Resque::Plugins::Status::Hash.get( @uuid )
        Resque.inline = false
      end
      it "executes job inline and updates status" do
        assert_equal "completed", @status["status"]
        assert !TestExtraLockedJob.locked?( @options )
        assert !TestLockedJob.locked?( @options )
      end
    end
  end
end
