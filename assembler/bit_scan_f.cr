module BitScanF
  VERSION = "0.0.5"

  def self.bit_scan_f(n : Int32, start : Int32)
    Array(Int32).build(32) do |p_buf|
      n_bits_up = uninitialized Int32
      asm("
xorl %eax, %eax
movl %eax, %esi		// esi: number of bits in <<up>> state
movq $3, %rdi
movl $2, %ecx
movl $1, %edx
inloop:
shrl %cl, %edx
orl %edx, %edx
jz outloop
incl %esi
bsf %edx, %ecx
addl %ecx, %eax
movl %eax, (%rdi)   	// mov DWORD PTR [rdi], eax
leaq 4(%rdi), %rdi  	// rdi += 4
incl %eax
incl %ecx
jmp inloop
outloop:
movl %esi, $0
"
              : "=r"(n_bits_up)
              : "r"(n), "r"(start), "r"(p_buf.address)
              : "rax", "rcx", "rdx", "rdi", "rsi")
      n_bits_up
    end
  end

  pp(bit_scan_f(ARGV[0]?.not_nil!.to_i, (ARGV[1]?.try &.to_i) || 0))
end
