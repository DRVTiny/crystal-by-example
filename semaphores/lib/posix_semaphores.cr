module POSIX
  lib C
  	struct SemT
  		{% begin %}
  		{% k=LibC::Int.class.stringify[3..4] %}
  		size : StaticArray(LibC::Char, {{k.id}})
  		{% end %}
  	end
  	alias ModeT = LibC::Int
    fun sem_open(name : UInt8*, flags: LibC::Int, mode : ModeT, value : LibC::UInt) : SemT*
    fun sem_init(sem : SemT*, pshared : LibC::Int, value : LibC::UInt) : LibC::Int
    fun sem_post(sem : SemT*) : LibC::Int
    fun sem_wait(sem : SemT*) : LibC::Int
    fun sem_unlink(sem : SemT*) : LibC::Int
    fun sem_destroy(sem : SemT*) : LibC::Int
  end
  
	class Semaphore
		getter name
		def initialize(@name : String, @mode = 0o666, @value = 0)
			@sem = C.sem_open(@name, LibC::O_CREAT, @mode, @value)
			if @sem.address == 0
				raise "semaphore creation failed!"
			end
			@sem
		end
		
		def remove
			C.sem_unlink(@sem)
		end
		
		def down
			C.sem_wait(@sem)
		end
		
		def up
			C.sem_post(@sem)
		end		
	end
end
