require "logger"
require "json"
require "file_utils"

N_CHILDREN    = 5
PROC_CTL_PATH = "/tmp/proc_respawn"
record Child, pid : Int32, slf : Process, status_pipe : IO::FileDescriptor

lib C
  fun getpgrp : LibC::Int
  fun setpgid(what_pid : LibC::Int, to_what_pgrpid : LibC::Int) : LibC::Int
end

class GlobalLogger
  @@logger = Logger.new(STDERR, Logger::DEBUG)

  def self.gimme
    @@logger
  end
end

class Cleaner
  def initialize
    @clean_procs = [] of Proc(Nil)
    @fs_objects = {files: [] of String, dirs: [] of String}
  end

  def add_proc(args : T, &block : T -> Int32) forall T
    @clean_procs.push(
      ->{
        block.call(args)
      })
  end

  {% for subst in ["file", "dir"] %}
		def add_{{subst.id}}(path : (Array(String)|String))
			if path.is_a?(Array(String))
				@fs_objects[:{{subst.id}}s].concat(path)
			else
				@fs_objects[:{{subst.id}}s].push(path)
			end
		end
	{% end %}

  def make_mrproper
    @clean_procs.each { |p| p.call }
    FileUtils.rm(@fs_objects[:files].select { |f| File.exists?(f) })
    FileUtils.rm_r(@fs_objects[:dirs].select { |d| File.exists?(d) })
  end
end

macro unix_ts
  {% if compare_versions(Crystal::VERSION, "0.27.0") >= 0 %}
    Time.now.to_unix
  {% else %}
    Time.now.epoch
  {% end %}
end

class CloningMachine
  MIN_TIME_BTW_FORKS = 5
  @children : Hash(Int32, Child)
  @sgnl_sigexit_rcvd : Channel(Nil)?
  @sgnl_sigchld_rcvd : Channel(Nil)?
  @cnt_failed_children : Int32
  @log : Logger
  @what2do : Proc(Int32)

  def initialize(@how_much_clones : Int32, @min_time_btw_forks = MIN_TIME_BTW_FORKS, wait_for_term = true, &block : Cleaner -> Int32)
    raise "Clones number is not valid" unless @how_much_clones > 0
    @cnt_failed_children, @cnt_forked_children = 0, 0
    @log = GlobalLogger.gimme
    @what2do = block
    #   C.setpgid(0, 0) unless C.getpgrp.to_i32 == Process.pid
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

    spawn do
      ts_prv_fork = Time.now.to_unix
      loop do
        if ch = @sgnl_sigchld_rcvd
          ch.receive
        end
        if (ts_delta = @min_time_btw_forks.to_i64 - (unix_ts - ts_prv_fork)) > 0
          @log.warn("Respawning too fast, wait for #{ts_delta} sec to do next fork")
          sleep ts_delta
        end

        @children.each do |child_pid, child|
          child_p = child.slf
          if child_p.terminated?
            @log.info "parent: child ##{child_pid} exited"
            exit_status = child_p.wait.exit_status
            @cnt_failed_children = @cnt_failed_children + 1 if (exit_status & 0x7f) > 0
            child.status_pipe.finalize
            @children.delete(child_pid)
            new_child = fork_me
            ts_prv_fork = unix_ts
            @children[new_child.pid] = new_child
          end
        end
        show_clones
      end
    end

    {% for sgnl in %w(HUP TERM INT) %}
      Signal::{{sgnl.id}}.trap do
        Signal::{{sgnl.id}}.ignore
      	if ch = @sgnl_sigexit_rcvd
          ch.send(nil)
        end
      end
    {% end %}
    ch_wait_for_term = Channel(Int32).new
    spawn do
      if ch = @sgnl_sigexit_rcvd
        ch.receive
      end
      @sgnl_sigchld_rcvd = nil
      @sgnl_sigexit_rcvd = nil

      @log.warn "Some of the exit signals received, terminating all forked processes"
      show_clones
      # Send TERM to all prrocesses in the process group which we lead
      Process.kill(Signal::TERM, 0)
      @children.each do |child_pid, child|
        child_p = child.slf
        if child_p.terminated?
          @log.debug("OK, forked process ##{child_pid} terminated normaly")
        else
          @log.warn("Forked process ##{child_pid} not killed by broadcasted TERM. Sending TERM (15) to him individually")
          unless forced_kill(child_p)
            @log.error("After all we still can't terminate forked process ##{child_pid} for some (mysterious) reasons")
          end
        end
        check_status_of_dead_process child_p
      end
      if ch_wait_for_term
        ch_wait_for_term.send(@cnt_failed_children)
      else
        exit @cnt_failed_children
      end
    end

    if wait_for_term
      exit ch_wait_for_term.receive
    end
  end

  def forced_kill(p : Process) : Bool
    2.times do |i|
      p.kill(Signal.from_value(15 - 6 * i))
      sleep 0.1
      break if p.terminated?
      puts "process #{p.pid} dont want to die, trying more serious pressure..."
    end
    p.terminated? ? true : false
  end

  def check_status_of_dead_process(p : Process)
    @cnt_failed_children = @cnt_failed_children + 1 if p.terminated? && ((p.wait.exit_status & 0x7f) > 0)
  end

  def fork_me : Child
    comm_pipe_read, comm_pipe_write = IO.pipe

    my_clone = Process.fork do
      Signal::CHLD.ignore
      cleaner = Cleaner.new
      ch_catch_to_clean = Channel(Cleaner).new
      {% for sgnl in %w(HUP TERM INT) %}
        Signal::{{sgnl.id}}.trap { ch_catch_to_clean.send(cleaner) }
      {% end %}
      spawn do
        ch_catch_to_clean.receive.make_mrproper
      end
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
    @cnt_forked_children = @cnt_forked_children + 1
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
