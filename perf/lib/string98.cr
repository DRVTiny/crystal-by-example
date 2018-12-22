# TODO: Write documentation for `String98`
VERSION = "0.1.0"
enum Char98
  TAB = 9
  LF = 10
  CR = 13
  Space = 32
  Exclam = 33
  DblQuote = 34
  Hash = 35
  Dollar = 36
  Percent = 37
  Ampers = 38
  SnglQuote = 39
  O_Paren = 40
  C_Paren = 41
  Ast = 42
  Plus = 43
  Comma = 44
  Minus = 45
  Dot = 46
  Slash = 47
  
  {% for code in (48..57) %}
  	Dig_{{code.id.to_i - 48}} = {{code.id}}
  {% end %}
  
  Colon = 58
  SemColon = 59
  Less = 60
  Equal = 61
  Greater = 62
  Question = 63
  At = 64
  
	{% begin %}
    {% code = 65 %}
    {% for ltr in %w[A B C D E F G H I J K L M N O P Q R S T U V W X Y Z] %}
      Ltr_{{ltr.id}} = {{code.id}}
    {% code = code + 1 %}
    {% end %}
  {% end %}
  
  O_SquareBrk = 91
  Backslash = 92
  C_SquareBrk = 93
  Caret = 94
  Underscore = 95
  GraveAcc = 96
  
  {% begin %}
    {% code = 97 %}
    {% for ltr in %w[a b c d e f g h i j k l m n o p q r s t u v w x y z] %}
      Ltr_{{ltr.id}} = {{code.id}}
    {% code = code + 1 %}
    {% end %}
  {% end %}
  
  O_CurlyBrck = 123
  Vbar = 124
  C_CurlyBrck = 125
  Tilde = 126
#  def value
#  	self.to_u8
#  end
  def to_s(io)
  	io.write_byte(self.value.to_u8)
  end
end

class String98
	@s98 : Slice(LibC::Char)
	getter size : Int32
	
	def initialize(s : String)
		cnt = 0
		s.each_codepoint do |code_pt|
			Char98.from_value(code_pt)
			cnt += 1
		end
		raise "Empty strings not acceptable to build String98" if cnt == 0
		p = Pointer(LibC::Char).malloc(cnt.to_u64)
		p.copy_from(s.to_unsafe, cnt)
		@size = cnt
		@s98 = p.to_slice(cnt)
	end
	
	def to_s(io)
		p = @s98.to_unsafe
		@s98.size.times {|i| io << p[i].unsafe_chr }
	end
	
	def to_s
		String.new(@s98)
	end
	
	def [](index : Int)
		raise IndexError.new unless 0 <= index < @s98.size
		Char98.from_value @s98[index]
	end
end
