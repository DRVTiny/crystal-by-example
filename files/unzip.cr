require "compress/zip"

module ZipUnpack
  VERSION = "0.0.3"
  zip_file_pth = ARGV[0]?.not_nil!
  zip_file_pth =~ /\.zip$/ || raise "file extension must be '.zip'"
  Compress::Zip::File.open(zip_file_pth) do |zip_file|
    csh = {} of String => Bool
    zip_file.entries.each do |z_entry|
      z_path = z_entry.filename

      puts "File: #{z_path}"
      csh[z_path]? && next
      if z_path =~ /\/$/
        Dir.mkdir_p z_path
      else
        File.open(z_path, "w") do |unpacked_file|
          unpacked_file.print z_entry.open { |io| io.gets_to_end }
        end
      end
      csh[z_path] = true
    end
  end
end
