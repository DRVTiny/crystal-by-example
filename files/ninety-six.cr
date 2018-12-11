require "option_parser"

class CharCount
  property all, nt, _96
  def initialize(@all = 0, @nt = 0, @_96 = 0)
  end
  
	def to_tuple
		{@all, @nt, @_96}
	end  
	
  def +(another : CharCount)
    CharCount.new(@all + another.all, @nt + another.nt, @_96 + another._96)
  end
end

class SkyWalker
  property chan, fib_count, stats : CharCount?
  property regex_fname : Regex
  property debug : Bool
  
  def initialize(@debug = false)
    @chan = Channel(CharCount?).new
    @fib_count = 0
    @stats = nil
    @regex_fname = /./
  end
  
  def print_stats!
  	raise "Please, call walk_path! method before trying to output any statistics" unless @stats
  	cnt_all, cnt_nt, cnt_96 = @stats.not_nil!.to_tuple
  	if cnt_all == 0
  		puts "No characters were classified"
  	else
  		puts "Overall characters readed: #{cnt_all}"
  		if cnt_96 > 0
	  		puts "Prtintable ASCII characters (aka 96): #{cnt_96}"
	  		puts "% of 96 group: #{(cnt_96.to_f/cnt_all) * 100.0}"
	  		puts "% of 96 group among non-CRLF chars: #{(cnt_96.to_f/(cnt_all - cnt_nt)) * 100.0}"
	  	else
	  		puts "No printable ASCII symbols found"
	  	end
  	end
  end
  
  def walk_path!(path : String, rx : Regex?, &block : String -> CharCount?) : CharCount
#  	@regex_fname = rx if rx
    walk_path_rx(path, rx, block)
    result_cnt = CharCount.new
    @fib_count.times do
    	if c = @chan.receive
      	result_cnt = result_cnt + c
      end
    end
    @stats = result_cnt
  end
  
  private def walk_path_rx(path : String, rx : Regex?, clos : String -> CharCount?)
    Dir.cd(path) do
      Dir.children(path).select {|f| File.exists?(f)}.each do |nstd_path|
        f_full_path = File.real_path(nstd_path)
        if File.directory?(nstd_path)
        	if File.executable?(nstd_path) && File.readable?(nstd_path)
	          walk_path_rx(f_full_path, rx, clos)
	        end
        elsif ! (File.empty?(nstd_path) || File.symlink?(nstd_path)) && (!rx || nstd_path.match(rx))
        	puts "processing file #{nstd_path}" if @debug
          @fib_count = @fib_count + 1
          spawn do
            @chan.send clos.call(f_full_path)
          end
        end
      end
    end
  end
end

base_path = "./"
rx = nil
fl_debug = false

OptionParser.parse! do |parser|
	parser.banner = "Usage: %c [arguments]"
	parser.on("-p BASE_DIR", "--path=BASE_DIR", "Path to directory where to search for files") {|p|  base_path = p }
	parser.on("-r REGEXP", "--regex=REGEXP", "Regexp to match file names by") {|r| rx = Regex.new(r) }
	parser.on("-x", "--debug", "Turn on debugging") { fl_debug = true }
  parser.on("-h", "--help", "Show this help") { puts parser }
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end	
end

luke = SkyWalker.new(debug: fl_debug)
luke.walk_path!(base_path, rx) do |f_path|
  count = CharCount.new
  File.open(f_path).each_char do |ch|
    count.all = count.all + 1
    next if ((ch_code = ch.ord) & ~127) > 0
    if 32 <= ch_code <= 127
      count._96 = count._96 + 1
    elsif ch_code == 13 || ch_code == 10
      count.nt = count.nt + 1
    end
  end
  count
rescue ex
	puts "Cant read file #{f_path}: #{ex.message}"
end

luke.print_stats!
