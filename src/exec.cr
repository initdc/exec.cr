class Exec < Process
  VERSION = "0.2.2"

  # https://github.com/crystal-lang/crystal/blob/1.19.1/src/compiler/crystal/macros/macros.cr#L68
  record Err, stdout : String, stderr : String, status : Process::Status

  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = true,
               input : Stdio = Redirect::Inherit, output : Stdio = Redirect::Inherit, error : Stdio = Redirect::Inherit, chdir : Path | String? = nil) : String | Err
    output_strio = String::Builder.new
    error_strio = String::Builder.new

    output_writer = if output.is_a?(Redirect)
                      output == Redirect::Close ? output : IO::MultiWriter.new(STDOUT, output_strio)
                    else
                      output != STDOUT ? IO::MultiWriter.new(STDOUT, output, output_strio) : IO::MultiWriter.new(STDOUT, output_strio)
                    end

    error_writer = if error.is_a?(Redirect)
                     error == Redirect::Close ? error : IO::MultiWriter.new(STDERR, error_strio)
                   else
                     error != STDERR ? IO::MultiWriter.new(STDERR, error, error_strio) : IO::MultiWriter.new(STDERR, error_strio)
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
      Err.new(output_strio.to_s, error_strio.to_s, status)
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
