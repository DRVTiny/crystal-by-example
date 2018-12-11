require "../processes/lib/cleaner"
require "./lib/posix_semaphores"

module My
  @@start_ts : Int64 = Time.now.to_unix
  @@sem = POSIX::Semaphore.new("/abcdef")
  @@clnr = Cleaner.new

  def self.get_sem
    @@sem
  end

  def self.set_sig
    LibC.signal Signal::HUP.value, ->(s : Int32) {}
    LibC.signal Signal::USR1.value, ->(s : Int32) do
      @@sem.up
    end
  end

  def self.start_ts
    @@start_ts
  end

  def self.cleaner
    @@clnr
  end

  def self.fire_guard
    t = Thread.new do
      @@sem.blocking_down
      @@clnr.make_mrproper
      puts "DONE after #{Time.now.to_unix - My.start_ts} sec."
      LibC._exit(1)
    end
  end
end

File.write(file_name = "/tmp/#{Process.pid}", "#{Process.pid}")
sem_val, _ = My.get_sem.value
puts "pid=#{Process.pid} ts=#{My.start_ts} file=#{file_name} sem_val=#{sem_val}\nExecute `kill -USR1 #{Process.pid}` in other console to unlock semaphore!\n"

My.cleaner.add_file(file_name)
My.cleaner.add_proc(["don't", "worry", "be", "happy"]) do |arr|
  puts %(cleaning proc is glad to tell you: #{arr.join(" ")})
  1
end
My.set_sig
My.fire_guard

puts "Start infinite calculation loop"
c = 0
loop do
  c = c + rand(3) - 1
end
