module TraceRuby
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
    def highlight(text, type: :ruby)
      case type
      when :ruby
        highlight_ruby text
      when :help_screen
        highlight_help_screen text
      else
        text.to_s
      end
    end

    def highlight_default(text)
      text.to_s
    end
    alias highlight_ruby highlight_default
    alias highlight_help_screen highlight_default
  end


  class TtyOut < Out
    def winsize
      stdout.winsize
    end

    def interpret(obj)
      return "" if obj == :last_line
      return ANSI.fetch obj, &:to_s unless Array === obj
      name, *args = obj
      ANSI.fetch(name).(*args)
    end

    def highlight_default(text)
      highlight_ruby text
    end

    def highlight_help_screen(text)
      text.gsub /^(  \S+)/, "\e[95m\\1\e[0m"
    end

    def highlight_ruby(ruby)
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
end
