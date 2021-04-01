# Build me this way:
# $	crystal build -Dpreview_mt --release unzip_fiberized.cr
# And run me in this manner:
# $ CRYSTAL_WORKERS=$(nproc) ./unzip_fiberized.cr path/to/file.zip
require "compress/zip"

lib LibC
	fun fflush(b : Void*)
	#		fun printf(format : Char*, ...) : Int32
end

module ZipUnpackFiberized
	VERSION = "0.0.1"
	
  def self.log(s)
		t = Thread.current.to_s rescue "Unknown"
		f = Fiber.current.to_s rescue "Unknown"
		LibC.printf("%s::%s >>> %s\n", t, f, s)
		LibC.fflush(nil)
  end
  
	zip_file_pth = ARGV[0]?.not_nil!
	zip_file_pth =~ /\.zip$/ || raise "file extension must be '.zip'"
	Compress::Zip::File.open(zip_file_pth) do |zip_file|
	
		files2extract = [] of Compress::Zip::File::Entry
		zip_file.entries.each do |ze|
			if (pth = ze.filename) =~ /\/$/
				Dir.mkdir_p pth
			else
				files2extract.push ze
			end
		end
		
		n_proc = Crystal::System.cpu_count
		n_files = files2extract.size 
		n_files_per_thread =  n_files // n_proc
		rmn_files =           n_files % n_proc
	
		ch_end = Channel(Nil).new
		si, ei = 0, 0
		n_proc.times do
			ei = si + n_files_per_thread + (rmn_files > 0 ? 1 : 0) - 1
			rmn_files -= 1
			ssi, eei = si, ei
			spawn do
				(ssi..eei).each do |i|
					z_entry = files2extract[i]
#					log "extracting file #{z_entry.filename}"
					File.open(z_entry.filename, "w") do |unpacked_file|
						z_entry.open {|z_io| IO.copy z_io, unpacked_file}
					end
				end
				ch_end.send(nil)
			end
			si = ei + 1
		end
		
		n_proc.times { ch_end.receive }
	end
end
