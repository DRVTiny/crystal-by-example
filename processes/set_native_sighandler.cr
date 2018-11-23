require "./lib/cleaner"

lib C
  fun printf(format : UInt8*, ...) : LibC::Int
  fun sleep(n : LibC::Int)
end

puts "pid=#{Process.pid} ppid=#{Process.ppid}"

ch_clean_exit = Channel(String).new

module Crystool::LoS
  # i.e. Lord of the Signals :)
  @@pigs_of_the_lord = ["naf-naf", "nif-nif", "nuf-nuf"]
  @@cleaner = ::Cleaner.new

  def self.set_signal(signal : ::Signal)
    LibC.signal signal.value, ->(sgnl : Int32) do
      C.printf("Uh-oh, %s received!\n", ::Signal.from_value(sgnl).to_s)

      #			pigs.each do |p|
      #				C.printf("%s!\n", p)
      #			end
      cleaner.make_mrproper
      #			LibC._exit(1)
    end
  end

  def self.cleaner
    @@cleaner
  end

  private def self.pigs
    @@pigs_of_the_lord
    #		["naf-naf", "nif-nif", "nuf-nuf"]
  end
end

class Counter
  def initialize
    @count = 0_u64
  end

  def incr
    @count = @count + 1
  end

  def count
    @count
  end
end

cnt = Counter.new
Crystool::LoS.cleaner.add_file("/tmp/#{Process.pid}")
# Crystool::LoS.cleaner.add_proc(cnt) do |counter|
#	counter.incr
#	1
# end
Crystool::LoS.set_signal(Signal::HUP)

spawn do
  puts ch_clean_exit.receive
  exit
end

ch_inf = Channel(Nil).new
pid = Process.pid
spawn do
  c : Int64 = 0
  loop do
    c = c + rand(3) - 1
    printf "%s\n", "pid=#{pid}, c=#{c}, cnt=#{cnt.count}"
  end
  ch_inf.send(nil)
end

ch_inf.receive
