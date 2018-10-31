require "logger"
log = Logger.new(STDERR, Logger::DEBUG)

def children_out_proc(forked_procs, logger : Logger)
	->{ logger.info "parent: my children (n=#{forked_procs.size}) are:\n\t" + forked_procs.keys.join("\n\t") + "\n " }
end

TMPDIR = "/tmp/proc_respawn"
N_CHILDREN = 5

Signal::USR1.trap do
        log.info "parent(SIGUSR1): catched"
end

forkedProc = ->() do
    {% for sgnl in %w(HUP TERM INT) %}
	    Signal::{{sgnl.id}}.trap { exit } 
    {% end %}
    wait4file = "#{TMPDIR}/#{Process.pid}"
    log.info "child##{Process.pid}: starting to poll for file #{wait4file} appearing"
    begin 
        loop do
            if File.exists?(wait4file)
                log.info "child##{Process.pid}: my file #{wait4file} is here, so raising exception"
                raise ""
            end
            sleep 1
        end
    rescue
        File.delete(wait4file) if File.exists?(wait4file)
        Process.kill(Signal::USR1, Process.ppid)
        exit(1)
    end
end

i = 0
children = (1..N_CHILDREN).map do |proc_n|
    log.info "parent: initially spawning (#{proc_n}) child"
    child = Process.fork &forkedProc
    log.info "parent: forked child ##{child.pid}"
    {child.pid, child}
end.to_h

do_show_children = children_out_proc(children, log)
do_show_children.call

sgnl_sigexit_rcvd = Channel(Nil).new
sgnl_sigchld_rcvd : Channel(Nil)? = Channel(Nil).new

Signal::CHLD.trap do
        log.info "parent(SIGCHLD): forked proc exited"
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
	log.warn "Some of the exit signals received, we have to kill all forked processes"
	do_show_children.call

    children.each do |child_pid, child|
        if child.terminated?
                log.warn( "Child ##{child_pid} already terminated" )
        else
                log.debug("Sending signal TERM (15) to process #{child_pid}")
                child.kill
                child.wait
        end
        log.error( "Cant terminate child ##{child_pid}" ) unless child.terminated?
    end
    exit
end

loop do
		if ch = sgnl_sigchld_rcvd
	        ch.receive
	    end
	    
        children.each do |child_pid, child|
        	if child.terminated?
        		log.info "parent: child ##{child_pid} exited"
        		children.delete(child_pid)
        		new_child = Process.fork &forkedProc
        		children[new_child.pid] = new_child
        	end
        end
        do_show_children.call
end
