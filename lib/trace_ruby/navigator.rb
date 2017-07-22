require 'trace_ruby/log'

module TraceRuby
  class FileCursor
    def initialize(stream)
      @stream = stream
      @events = []
      @index  = 0
      until stream.eof?
        len = ''
        loop do
          chr = stream.readbyte.chr
          break if chr == ':'
          len << chr
        end
        @events << Marshal.load(stream.read len.to_i)
      end
    end

    def index
      @index
    end

    def length
      @events.length
    end

    include Enumerable
    def each(&block)
      @events.each(&block)
    end

    def crnt
      @events[@index]
    end

    def next
      move_bounded +1
    end

    def prev # FIXME untested
      move_bounded -1
    end

    def to_first
      @index = 0
    end

    def to_last
      @index = length - 1
    end

    def last?
      @index == length - 1
    end

    def to_index(index)
      disparity = index-@index
      disparity.abs.times &(
        if   disparity.negative?
        then proc { self.prev }
        else proc { self.next }
        end
      )
    end

    # FIXME UNTESTED
    private def move_bounded(offset)
      @index += offset
      to_last if after_last?
      to_first if before_first?
    end

    private def before_first?
      @index < 0
    end

    private def after_last?
      length <= @index
    end
  end

  class Navigator
    def self.from_stream(stream)
      new cursor: FileCursor.new(stream)
    end

    def initialize(cursor:)
      @cursor = cursor
    end

    def length
      @cursor.length
    end

    def crnt
      @cursor.crnt
    end

    def next
      @cursor.next
      self
    end

    def prev
      @cursor.prev
      self
    end

    def to_index(index)
      @cursor.to_index index
      self
    end

    def to_first
      @cursor.to_first
      self
    end

    def to_last
      @cursor.to_last
      self
    end

    def index
      @cursor.index
    end

    def prefix_each
      return to_enum :prefix_each unless block_given?
      depth = 0
      loop do
        yield crnt
        if @cursor.last?
          break
        elsif depth.zero? && crnt.end?
          break
        elsif crnt.end?
          depth -= 1
          @cursor.next
        elsif crnt.begin?
          depth += 1
          @cursor.next
        else
          @cursor.next
        end
      end
      self
    end

    def skip(matcher)
      self.next while match_file?(matcher) && !@cursor.last?
    end

    def search_forward(matcher)
      matchers = []
      matchers << -> { @cursor.last? }
      matchers << -> { match_file?  matcher } if Regexp === matcher || String === matcher
      matchers << -> { match_event? matcher } if Symbol === matcher
      self.next
      self.next until matchers.any? &:call
    end

    def search_backward(matcher)
      self.prev until match_file?(matcher) || @cursor.first?
    end

    private def match_file?(matcher)
      crnt.fetch(:path)&.[](matcher)
    end

    private def match_event?(event)
      crnt.fetch(:event) == event
    end
  end
end
