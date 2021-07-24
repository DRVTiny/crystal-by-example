class Barrier
  @counter : UInt32
  @chan : Channel(Int32)
  @lock : Mutex
  getter opened : Bool
  def initialize(@capacity : UInt32)
    raise "barrier's capacity must be >=2" if @capacity < 2
    @chan = get_chan
    @counter = 0
#    @mutexes = (0..@capacity-2).map do
#      mu = Mutex.new(protection: :unchecked)
#      mu.lock
#      mu
#    end
    @lock = Mutex.new
    @opened = false
  end
  
  def in
    @lock.lock
    raise "barrier already opened" if @opened
#    mutex_id = @counter
    if (@counter += 1) == @capacity
      @capacity.times { @chan.send(1) }
#      @mutexes.each {|mu| mu.unlock}
      @counter = 0
      @opened = true
      @lock.unlock
    else
      @lock.unlock
#      @mutexes[mutex_id].lock
      @chan.receive
    end
  end
  
  def out
    @lock.lock
    raise "barrier is already closed" unless @opened
    if (@counter -= 1) == 0
      @chan.close
      @chan = get_chan
      @opened = false      
    elsif @counter < 0
      raise "barrier underrun"      
    end
  ensure
    @lock.unlock
  end
  
  private def get_chan
    Channel(Int32).new(@capacity.to_i32)
  end
end

n_threads = (ENV["CRYSTAL_WORKERS"]? || Crystal::System.cpu_count).to_u32
c = 0
bar = Barrier.new(n_threads)
ch_fin = Channel(Nil).new
n_threads.times do
  spawn do
    bar.in
    1000.times { c += 1 }
    ch_fin.send(nil)
  end
end

n_threads.times { ch_fin.receive }
puts "c=#{c}"
