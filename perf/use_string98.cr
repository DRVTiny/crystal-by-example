require "./lib/string98.cr"
# 											012345678901234567890
ascii_s = String98.new("abcedfhjhjkh758493k&_")
puts ascii_s.to_s
puts ascii_s
ascii_s.size.times do |i|
	puts ascii_s[i]
end
