class Exec < Process
  VERSION = "0.2.1"

  class IO
    class MultiWriter < ::IO::MultiWriter
      alias IO = ::IO | ::IO::FileDescriptor | ::String::Builder

      def read(slice : Bytes) : NoReturn
        raise ::IO::Error.new("Can't read from IO::MultiWriter")
      end
    end
  end

  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = true,
               input : Stdio = Redirect::Inherit, output : Stdio = Redirect::Inherit, error : Stdio = Redirect::Inherit, chdir : Path | String? = nil) : String | {String, String, Process::Status}
    output_strio = String::Builder.new
    error_strio = String::Builder.new

    output_writer = if output.is_a?(Redirect)
                      output == Redirect::Close ? output : Exec::IO::MultiWriter.new(STDOUT, output_strio)
                    else
                      output != STDOUT ? Exec::IO::MultiWriter.new(STDOUT, output, output_strio) : Exec::IO::MultiWriter.new(STDOUT, output_strio)
                    end

    error_writer = if error.is_a?(Redirect)
                     error == Redirect::Close ? error : Exec::IO::MultiWriter.new(STDERR, error_strio)
                   else
                     error != STDERR ? Exec::IO::MultiWriter.new(STDERR, error, error_strio) : Exec::IO::MultiWriter.new(STDERR, error_strio)
                   end

    status = new(command, args, env, clear_env, shell, input, output_writer, error_writer, chdir).wait
    $? = status

    output.close unless output.is_a?(Redirect) || output == STDOUT
    error.close unless error.is_a?(Redirect) || error == STDERR
    output_strio.close
    error_strio.close

    case status.success?
    when true
      output_strio.to_s
    else
      {output_strio.to_s, error_strio.to_s, status}
    end
  end

  def self.code(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = true,
                input : Stdio = Redirect::Inherit, output : Stdio = Redirect::Inherit, error : Stdio = Redirect::Inherit, chdir : Path | String? = nil) : Int32
    status = new(command, args, env, clear_env, shell, input, output, error, chdir).wait
    $? = status
    status.exit_code
  rescue File::NotFoundError
    127
  end

  def self.output(command, chomp = true) : String
    process = new(command, shell: true, input: Redirect::Inherit, output: Redirect::Pipe, error: Redirect::Inherit)
    output = process.output.gets_to_end
    status = process.wait
    $? = status
    return output.chomp if chomp
    output
  end

  def self.each_line(command, chomp = false, & : String ->) : Nil
    process = new(command, shell: true, input: Redirect::Inherit, output: Redirect::Pipe, error: Redirect::Inherit)
    begin
      process.output.each_line(chomp) do |line|
        yield line
      end
      status = process.wait
      $? = status
    rescue ex
      process.terminate
      raise ex
    end
  end

  def self.each_line(command, chomp = false) : Array(String)
    process = new(command, shell: true, input: Redirect::Inherit, output: Redirect::Pipe, error: Redirect::Inherit)
    arr = process.output.each_line(chomp).to_a
    status = process.wait
    $? = status
    arr
  end
end
