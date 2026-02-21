class Exec < Process
  VERSION = "0.1.2"

  class Status < ::Process::Status
    getter stdout : String
    getter stderr : String

    {% if flag?(:win32) %}
      # :nodoc:
      def initialize(@exit_status : UInt32, @stdout : String, @stderr : String)
      end
    {% else %}
      # :nodoc:
      def initialize(@exit_status : Int32, @stdout : String, @stderr : String)
      end
    {% end %}
  end

  def self.run(command : String, args = nil, env : Env = nil, clear_env : Bool = false, shell : Bool = true,
               input : IO = STDIN, output : IO | Array(IO) = STDOUT, error : IO | Array(IO) = STDERR, chdir : Path | String? = nil) : Status
    output_strio = String::Builder.new
    error_strio = String::Builder.new
    output_writer = output.is_a?(Array) ? IO::MultiWriter.new(output + output_strio) : IO::MultiWriter.new(output, output_strio)
    error_writer = error.is_a?(Array) ? IO::MultiWriter.new(error + error_strio) : IO::MultiWriter.new(error, error_strio)

    status = new(command, args, env, clear_env, shell, input, output_writer, error_writer, chdir).wait
    $? = status

    output_writer.close
    error_writer.close
    Status.new(status.@exit_status, output_strio.to_s, error_strio.to_s)
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

  def self.each_line(command, chomp = false, &block : String ->) : Nil
    process = new(command, shell: true, input: Redirect::Inherit, output: Redirect::Pipe, error: Redirect::Inherit)
    output = process.output.gets_to_end
    status = process.wait
    $? = status
    output.each_line(chomp) do |line|
      yield line
    end
  end

  def self.each_line(command, chomp = false)
    process = new(command, shell: true, input: Redirect::Inherit, output: Redirect::Pipe, error: Redirect::Inherit)
    output = process.output.gets_to_end
    status = process.wait
    $? = status
    output.each_line(chomp).to_a
  end
end
