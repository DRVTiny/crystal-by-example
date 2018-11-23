require "file_utils"

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
