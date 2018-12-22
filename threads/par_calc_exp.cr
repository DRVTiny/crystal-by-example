module Calc
  @@facts : Array(UInt64) = [1_u64]
  def self.fact(x : Int32) : UInt64
    if (knofind =  @@facts.size) < x
      acc_f = @@facts[knofind-1]
      ((knofind + 1).to_u64..x.to_u64).each do |v|
        raise "Cant calculate intermediate fact(#{v}): value too big for #{v.class}" if (acc_f *= v) == 0
        @@facts.push(acc_f) if @@facts.size < v
      end
    end
    @@facts[x-1]
  end
end

DFLT_EXP_POWER = 1
DFLT_SERIES_ELS = 32
N_THREADS_P2 = 3
N_THREADS = 1 << N_THREADS_P2
LAST_THR_ID = N_THREADS - 1

e_power = ((ARGV[0]?.try &.to_i) || DFLT_EXP_POWER).to_f64
n_elems_after0 = (ARGV[1]?.try &.to_i) || DFLT_SERIES_ELS
n_elems_per_thr = (n_elems_after0 >> N_THREADS_P2)

sums = Array.new(N_THREADS) { 0_f64 } 
threads = Array.new(N_THREADS) do |thread_n| 
  Thread.new do
    sum = 0_f64
    start_el = 1 + n_elems_per_thr * thread_n
    stop_el = (thread_n == LAST_THR_ID) ? n_elems_after0 : (start_el + n_elems_per_thr - 1)
    if e_power > 1
      (start_el..stop_el).each { |n| sum += (e_power ** n).to_f64 / Calc.fact(n)  } 
    else
      (start_el..stop_el).each { |n| sum += 1_f64 / Calc.fact(n)  }
    end
    sums[thread_n] = sum
  end
end

(1..threads.size).each do |ind|
  threads[-ind].join
end

puts "e=#{1 + sums.reduce {|acc_sum, s| acc_sum += s }}"
