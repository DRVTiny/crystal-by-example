require "./lib/posix_semaphores"
sem = POSIX::Semaphore.new("/pid#{Process.pid}_01")
puts "Semaphore created (locked by default)"
start_ts = Time.now.to_unix
spawn do
  sleep 2
  sem.up
  puts "Unlocked semaphore after #{Time.now.to_unix - start_ts} sec."  
end

spawn do
  5.times do |c|
    sleep 0.5
    puts "processing operations, step ##{c+1}..."
  end
end

sem.down
