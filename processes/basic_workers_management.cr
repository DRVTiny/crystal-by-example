require "logger"
N_CHILDREN = 5

record Child, pid : Int32, slf : Process, status_pipe : IO::FileDescriptor

class CloningMachine
	DFLT_PROC_DIR     = "/tmp/proc_respawn"	
	@children : Hash(Int32, Child)
	
	def initialize(@how_much_clones : Int32, @log : Logger = Logger.new(STDERR), @tmp_dir = DFLT_PROC_DIR)
		raise "Clones number is not valid" unless @how_much_clones > 0
    @children = (1..@how_much_clones).map do |proc_n|
      log.info "parent: initially spawning (#{proc_n}) child"
      child = fork_me
      log.info "parent: forked child ##{child.pid}"
      {child.pid, child}
    end.to_h
    
    sgnl_sigexit_rcvd = Channel(Nil).new
    sgnl_sigchld_rcvd : Channel(Nil)? = Channel(Nil).new

    Signal::CHLD.trap do
      @log.info "parent(SIGCHLD): forked proc exited"
      if ch = sgnl_sigchld_rcvd
        ch.send(nil)
      end
    end

    {% for sgnl in %w(HUP TERM INT) %}
      Signal::{{sgnl.id}}.trap do
        sgnl_sigexit_rcvd.send(nil)
      end
    {% end %}

    spawn do
      sgnl_sigexit_rcvd.receive
      sgnl_sigchld_rcvd = nil
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

    loop do
      if ch = sgnl_sigchld_rcvd
        ch.receive
      end

      @children.each do |child_pid, child|
        if child.slf.terminated?
          @log.info "parent: child ##{child_pid} exited"
          @children.delete(child_pid)
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
      {% for sgnl in %w(HUP TERM INT) %}
        Signal::{{sgnl.id}}.trap { exit }
      {% end %}
      wait4file = "#{@tmp_dir}/#{Process.pid}"
      @log.info "child##{Process.pid}: starting to poll for file #{wait4file} appearing"
      begin
        loop do
          if File.exists?(wait4file)
            @log.info "child##{Process.pid}: my file #{wait4file} is here, so raising exception"
            raise ""
          end
          sleep 1
        end
      rescue
        File.delete(wait4file) if File.exists?(wait4file)
        comm_pipe_write.puts("i am ##{Process.pid}, i've succeed and i am gone")
        exit(1)
      end
    end
    
    spawn do
      begin
        res = comm_pipe_read.gets
        @log.warn("my child told me: #{res}")
      rescue
      end
    end
    
    Child.new(slf: my_clone, pid: my_clone.pid, status_pipe: comm_pipe_read)
  end
  
  def show_clones
  	@log.info "parent: my children (n=#{@children.size}) are:\n\t" + @children.keys.join("\n\t") + "\n"
  end
end

cm = CloningMachine.new(N_CHILDREN)
