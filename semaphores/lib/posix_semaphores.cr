module POSIX
  lib C
    struct SemT
      {% begin %}
        {% k = LibC::Int.class.stringify[3..4] %}
        size : StaticArray(LibC::Char, {{k.id}})
      {% end %}
    end

    alias ModeT = LibC::Int
    fun sem_open(name : UInt8*, flags : LibC::Int, mode : ModeT, value : LibC::UInt) : SemT*
    fun sem_init(sem : SemT*, pshared : LibC::Int, value : LibC::UInt) : LibC::Int
    fun sem_post(sem : SemT*) : LibC::Int
    fun sem_wait(sem : SemT*) : LibC::Int
    fun sem_unlink(sem : SemT*) : LibC::Int
    fun sem_destroy(sem : SemT*) : LibC::Int
    fun sem_getvalue(sem: SemT*, sem_value : LibC::Int*) : LibC::Int
    fun sem_trywait(sem: SemT*) : LibC::Int
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
      until C.sem_trywait(@sem) == 0
        case Errno.value
        when Errno::EAGAIN, Errno::EINTR
          Fiber.yield
          next
        else
          raise Errno.new("failed to wait for freeing semaphore #{@name}:") 
        end
      end
    end
    
    def blocking_down
      C.sem_wait(@sem)  
    end
    
    def up
      C.sem_post(@sem)
    end
    
    def value : Tuple(LibC::Int, LibC::Int?)
      C.sem_getvalue(@sem, out cur_sem_val)
      cur_sem_val > 0 ? {cur_sem_val, nil} : {0, cur_sem_val == 0 ? nil : cur_sem_val.abs} 
    end
  end
end
