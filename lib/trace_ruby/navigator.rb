require 'trace_ruby/log'

module TraceRuby
  class FileCursor
    def initialize(stream)
      @stream = stream
      @events = []
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

    def length
      @events.length
    end

    include Enumerable
    def each(&block)
      @events.each(&block)
    end
  end

  class Navigator
    def self.from_stream(stream)
      new index: 0, cursor: FileCursor.new(stream)
    end

    attr_reader :index

    def initialize(index:, cursor:)
      @index  = index
      @cursor = cursor
    end

    def length
      @cursor.length
    end

    def crnt
      @cursor[@index]
    end

    def next
      move_bounded @index+1
    end

    def prev
      move_bounded @index-1
    end

    def to_index(index)
      move_bounded index
    end

    def to_first
      @index = 0
    end

    def to_last
      @index = @cursor.length - 1
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

    private def move_bounded(index)
      @index = index
      to_last if after_last?
      to_first if before_first?
    end

    private def wrap_index(offset)
      @index += offset
      to_last  if before_first?
      to_first if after_last?
    end

    private def match_file?(matcher)
      crnt.fetch(:path)&.[](matcher)
    end

    private def match_event?(event)
      crnt.fetch(:event) == event
    end

    private def at_beginning?
      @index.zero?
    end

    private def at_end?
      @cursor.length == @index.succ
    end

    private def before_first?
      @index < 0
    end

    private def after_last?
      @cursor.length <= @index
    end
  end
end
