# Build me this way:
# $	crystal build -Dpreview_mt --release unzip_fiberized.cr
# And run me in this manner:
# $ CRYSTAL_WORKERS=$(nproc) ./unzip_fiberized.cr path/to/file.zip
require "compress/zip"

module ZipUnpackFiberized
  VERSION = "0.0.1"
	zip_file_pth = ARGV[0]?.not_nil!
	zip_file_pth =~ /\.zip$/ || raise "file extension must be '.zip'"
	Compress::Zip::File.open(zip_file_pth) do |zip_file|
		csh = {} of String => Bool
		files2extract = [] of Compress::Zip::File::Entry

		zip_file.entries.each do |ze|
			if (pth = ze.filename) =~ /\/$/
				Dir.mkdir_p pth
			else
				files2extract.push ze
			end
		end
		
		n_proc = Crystal::System.cpu_count		
		ch_buf_size = files2extract.size + n_proc
		ch_files = Channel(Compress::Zip::File::Entry | Nil).new(ch_buf_size)
		
		files2extract.each {|ze| ch_files.send(ze) }
		n_proc.times { ch_files.send(nil) }
		ch_end = Channel(Nil).new
		n_proc.times do
			spawn do
				while	z_entry = ch_files.receive
					File.open(z_entry.filename, "w") do |unpacked_file|
						unpacked_file.print z_entry.open {|io| io.gets_to_end }
					end
				end
				ch_end.send(nil)
			end
		end
		
		n_proc.times { ch_end.receive }
	end
end
