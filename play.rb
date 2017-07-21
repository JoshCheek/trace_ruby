require 'coderay'
require 'readline'
require 'io/console'

logname = ARGV[0] || Dir['*.log'].sort_by { |name| name.scan(/\d+/).map &:to_i }.last
logname or abort "No log file provided or found!"

def self.file_linenos(body)
  body.lines.map.with_index(1).to_a.map(&:reverse)
end

def self.files
  @files ||= Hash.new do |h, filename|
    body = File.exist?(filename) ?  File.read(filename) : ""
    h[filename] = body
  end
end

def display_file(log:, stdout:, height:, path:, lineno:, event:, method:nil, hide_filename: false, hide_linenos: false)
  header_size  = 2
  header_size -= 1 if hide_filename
  file_lines   = file_linenos stdout.highlight files[path]
  offset       = (height-header_size)/2
  start_line   = [1, lineno - offset].max
  stop_line    = [file_lines.length, lineno + offset].min
  stop_line   -= 1 if (height-header_size) <= (stop_line-start_line)
  lines        = file_lines[start_line-1..stop_line-1]
  stdout << :clear_screen
  stdout << :fg_blue << "===== " << log.index << ". "
  stdout << event
  stdout << " #{method}" if method
  stdout << " =====" << :reset << "\n"
  unless hide_filename
    stdout << :fg_magenta << path << :reset << ":" << :fg_yellow << lineno << :reset << "\n"
  end
  lineno_length = lines.map(&:first).max.to_s.length
  lines.each do |file_lineno, line|
    lineno_str = file_lineno.to_s.rjust(lineno_length)
    if lineno == file_lineno
      coloured_lineno = [:fg_black, :bg_yellow, lineno_str, :reset]
      delimiter       = [:fg_black, :bg_yellow, ":", :reset]
    else
      coloured_lineno = [:fg_yellow, lineno_str, :reset]
      delimiter       = [:fg_magenta, ":", :reset]
    end
    to_print = coloured_lineno + delimiter
    to_print = [] if hide_linenos
    if file_lineno == stop_line
      to_print << line.chomp
    else
      to_print << line
    end
    to_print.each { |e| stdout << e }
  end
  stdout << :last_line
end


class Log
  attr_reader :index
  def initialize(index:, logs:)
    @index = index
    @logs  = logs
  end

  def length
    @logs.length
  end

  def crnt
    @logs[@index]
  end

  def next
    wrap_index 1
  end

  def to_index(index)
    @index = index
    to_last if after_last?
    to_first if before_first?
  end

  def prev
    wrap_index -1
  end

  def to_first
    @index = 0
  end

  def to_last
    @index = @logs.length - 1
  end

  def skip(matcher)
    self.next while match_file?(matcher) && !at_end?
  end

  def search_forward(matcher)
    matchers = []
    matchers << -> { at_end? }
    matchers << -> { match_file?  matcher } if Regexp === matcher || String === matcher
    matchers << -> { match_event? matcher } if Symbol === matcher
    self.next
    self.next until matchers.any? &:call
  end

  def search_backward(matcher)
    self.prev until match_file?(matcher) || at_beginning?
  end

  private def wrap_index(offset)
    @index += offset
    to_last  if before_first?
    to_first if after_last?
  end

  private def match_file?(matcher)
    crnt.fetch(:path)[matcher]
  end

  private def match_event?(event)
    crnt.fetch(:event) == event
  end

  private def at_beginning?
    @index.zero?
  end

  private def at_end?
    @logs.length == @index.succ
  end

  private def before_first?
    @index < 0
  end

  private def after_last?
    @logs.length <= @index
  end
end

def self.read_logfile(filename)
  logs = []
  File.open filename, 'r' do |f|
    until f.eof?
      len = ''
      loop do
        chr = f.readbyte.chr
        break if chr == ':'
        len << chr
      end
      logs << Marshal.load(f.read len.to_i)
    end
  end
  logs
end

log = Log.new index: 0, logs: begin
  logs = read_logfile logname
  logs.unshift path: 'splash screen', lineno: 0, event: 'Play logs', hide_filename: true, hide_linenos: true
  splash_screen = <<~SPLASH_SCREEN
    Information
      log-file #{logname}
      num-logs #{logs.length}

    Controls
      j   To next
      k   To previous
      #   To log number
      g   To beginning
      G   To end
      s   Skip forward
      l   Skip to next line event
      /   Find forward
      ?   Find backward
      C-l Redraw
      q   Quit
  SPLASH_SCREEN
  files['splash screen'] = splash_screen
  def splash_screen.type
    :splash_screen
  end
  logs
end

class In < Struct.new(:stdin)
  def initialize(stdin:)
    super stdin
  end
end
class TtyIn < In
  def getch
    stdin.getch
  end
end
class FileIn < In
  def getch
    stdin.getc
  end
end

class Out < Struct.new(:stdout)
  ANSI = {
    clear_screen:   "\e[H\e[2J",
    clear_line:     "\e[K",

    fg_black:       "\e[30m",
    fg_red:         "\e[31m",
    fg_green:       "\e[32m",
    fg_yellow:      "\e[33m",
    fg_blue:        "\e[34m",
    fg_magenta:     "\e[35m",
    fg_cyan:        "\e[36m",
    fg_white:       "\e[37m",

    bg_black:       "\e[40m",
    bg_red:         "\e[41m",
    bg_green:       "\e[42m",
    bg_yellow:      "\e[43m",
    bg_blue:        "\e[44m",
    bg_magenta:     "\e[45m",
    bg_cyan:        "\e[46m",
    bg_white:       "\e[47m",

    reset:          "\e[0m",

    show_cursor:    "\e[?25h",
    hide_cursor:    "\e[?25l",
    goto_line:      -> lineno { "\e[#{lineno}H" },
  }

  def initialize(stdout:)
    super stdout
  end
  def print(*args)
    stdout.print(*args)
  end
  def puts(*args)
    stdout.puts(*args)
  end
  def hide_cursor
    self << :hide_cursor
  end
  def show_cursor
    self << :show_cursor
  end
  def goto_line(lineno)
    self << [:goto_line, lineno]
  end
  def clear_screen
    self << :clear_screen
  end
  def clear_line
    self << :clear_line
  end
  def <<(to_write)
    interpreted = interpret to_write
    print interpreted if interpreted
    self
  end
  def interpret(obj)
    obj.to_s
  end
  def highlight(text)
    return highlight_default text unless text.respond_to? :type
    case text.type
    when :ruby
      highlight_ruby text
    when :splash_screen
      highlight_splash_screen text
    else
      text.to_s
    end
  end

  def highlight_default(text)
    text.to_s
  end
  alias highlight_ruby highlight_default
  alias highlight_splash_screen highlight_default
end


class TtyOut < Out
  def winsize
    stdout.winsize
  end

  def interpret(obj)
    return "" if obj == :last_line
    return ANSI.fetch(obj) { obj.to_s } unless Array === obj
    name, *args = obj
    ANSI.fetch(name).call(*args)
  end

  def highlight_default(text)
    highlight_ruby text
  end

  def highlight_splash_screen(text)
    text.gsub /^(  \S+)/, "\e[95m\\1\e[0m"
  end

  private def highlight_ruby(ruby)
    CodeRay.encode ruby, :ruby, :terminal
  end
end


class FileOut < Out
  attr_accessor :height, :width
  def initialize(height:, width:, **rest)
    self.height = height
    self.width  = width
    super **rest
  end
  def winsize
    return height, width
  end
  def interpret(obj)
    return if ANSI.key? obj
    return if Array === obj && ANSI.key?(obj.first)
    return "\n" if obj === :last_line
    obj.to_s
  end
end

# polymorphism so we don't have to do if-statements everywhere
stdin  = $stdin.tty?  ? TtyIn.new(stdin: $stdin)    : FileIn.new(stdin: $stdin)
stdout = $stdout.tty? ? TtyOut.new(stdout: $stdout) : FileOut.new(stdout: $stdout, height: 50, width: 100)

# SIGWINCH gets sent when the terminal is resized
height, width = stdout.winsize
trap('SIGWINCH') { height, width = stdout.winsize }

# hide cursor when running, make sure to show again whenever we leave the program
stdout.hide_cursor
at_exit { stdout.show_cursor }

# SIGTSTP puts the process into the background, SIGCONT puts it into the foreground
bg_orig = nil
bg_trap = proc do
  stdout.show_cursor
  trap 'SIGTSTP', bg_orig
  Process.kill 'SIGTSTP', $$
end
bg_orig = trap 'SIGTSTP', &bg_trap
trap 'SIGCONT' do
  bg_orig = trap 'SIGTSTP', bg_trap
  stdout.hide_cursor
end

define_singleton_method :prompt do |message, lineno: height|
  stdout.goto_line lineno
  stdout.clear_line
  Readline.readline message, true
end



loop do
  display_file log: log, stdout: stdout, height: height, **log.crnt
  case stdin.getch
  when 'j', "\n"
    log.next
  when 'k'
    log.prev
  when  'g'
    log.to_first
  when 'G'
    log.to_last
  when '#'
    result = prompt('event number: ')
    index  = result.to_i
    log.to_index index if index.to_s == result
  when 's'
    log.skip prompt('skip: ')
  when 'l'
    log.search_forward :line
  when '/'
    log.search_forward prompt('search forward: ')
  when '?'
    log.search_backward prompt('search backward: ')
  when ?\C-l
    # noop, it draws at the beginning of the loop
  when ?\C-z
    Process.kill 'SIGTSTP', $$
  when 'q', 3.chr, 4.chr, nil
    break
  end
end
