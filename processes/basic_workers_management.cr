require "logger"
require "json"

N_CHILDREN = 5
PROC_CTL_PATH = "/tmp/proc_respawn"
record Child, pid : Int32, slf : Process, status_pipe : IO::FileDescriptor

class GlobalLogger
	@@logger = Logger.new(STDERR, Logger::DEBUG)
	def self.gimme
		@@logger
	end
end

class CloningMachine
	MIN_TIME_BTW_FORKS = 5
	@children : Hash(Int32, Child)
	@sgnl_sigexit_rcvd : Channel(Nil)?
	@sgnl_sigchld_rcvd : Channel(Nil)?
	@log : Logger
	@what2do : Proc(Int32)
	
	def initialize(@how_much_clones : Int32, @min_time_btw_forks = MIN_TIME_BTW_FORKS, &block: -> Int32)
		raise "Clones number is not valid" unless @how_much_clones > 0
		@log = GlobalLogger.gimme
		@what2do = block
    @children = (1..@how_much_clones).map do |proc_n|
      @log.info "parent: initially spawning (#{proc_n}) child"
      child = fork_me
      @log.info "parent: forked child ##{child.pid}"
      {child.pid, child}
    end.to_h
    
    @sgnl_sigexit_rcvd = Channel(Nil).new
    @sgnl_sigchld_rcvd = Channel(Nil).new

    Signal::CHLD.trap do
      @log.info "parent(SIGCHLD): forked proc exited"
      if ch = @sgnl_sigchld_rcvd
        ch.send(nil)
      end
    end

    {% for sgnl in %w(HUP TERM INT) %}
      Signal::{{sgnl.id}}.trap do
      	if ch = @sgnl_sigexit_rcvd
        	ch.send(nil)
        end
      end
    {% end %}

    spawn do
    	if ch = @sgnl_sigexit_rcvd
      	ch.receive
      end
      @sgnl_sigchld_rcvd = nil
      @sgnl_sigexit_rcvd = nil
      
      @log.warn "Some of the exit signals received, we have to kill all forked processes"
      show_clones

      @children.each do |child_pid, child|
        if child.slf.terminated?
          @log.warn("Child ##{child_pid} already terminated")
        else
          @log.debug("Sending signal TERM (15) to process #{child_pid}")
          child.slf.kill
          child.slf.wait
        end
        @log.error("Can't terminate child ##{child_pid}") unless child.slf.terminated?
      end
      
      exit
    end
    
    t = Time.new
		ts_prv_fork = t.epoch
    loop do
      if ch = @sgnl_sigchld_rcvd
        ch.receive
      end
      
			if (ts_delta = @min_time_btw_forks.to_i64 - (t.epoch - ts_prv_fork)) > 0
				@log.warn("Respawning too fast, wait for #{ts_delta} sec to do next fork")
				sleep ts_delta
			end
			
      @children.each do |child_pid, child|
        if child.slf.terminated?
          @log.info "parent: child ##{child_pid} exited"
          child.status_pipe.finalize
          @children.delete(child_pid)
          ts_prv_fork = t.epoch
          new_child = fork_me
          @children[new_child.pid] = new_child
        end
      end
      show_clones
    end
	end
	
  def fork_me : Child
    comm_pipe_read, comm_pipe_write = IO.pipe
    
    my_clone = Process.fork do
    	Signal::CHLD.ignore
      {% for sgnl in %w(HUP TERM INT) %}
        Signal::{{sgnl.id}}.reset
      {% end %}
      begin
	      exit(@what2do.call)
	    rescue ex
	    	comm_pipe_write.puts({error: ex.message}.to_json)
	    	exit(1)
	    end
    end
    
    spawn do
      begin
        res = comm_pipe_read.gets
        @log.warn(%<my child told me about error: #{(res ? JSON.parse(res)["error"]? : nil) || "nothing"}>)
      rescue
      end
    end
    
    Child.new(slf: my_clone, pid: my_clone.pid, status_pipe: comm_pipe_read)
  end
  
  def show_clones
  	@log.info "parent: my children (n=#{@children.size}) are:\n\t" + @children.keys.join("\n\t") + "\n"
  end
end

cm = CloningMachine.new(N_CHILDREN) do
    wait4file = "#{PROC_CTL_PATH}/#{Process.pid}"
    log = GlobalLogger.gimme
    log.info "child##{Process.pid}: starting to poll for file #{wait4file} appearing"
    loop do
      if File.exists?(wait4file)
        log.info "child##{Process.pid}: my file #{wait4file} is here, so raising exception"
        File.delete(wait4file) if File.exists?(wait4file)
        raise "Oh no, you've touched #{wait4file}!"
      end
      sleep 1
    end
    0
end
