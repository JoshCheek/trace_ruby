require 'trace_ruby/log'

def Record(*args, &block)
  TraceRuby::Record.call(*args, &block)
end

module TraceRuby
  class Record
    IGNORE_FILES = []
    IGNORE_FILES << File.expand_path(__FILE__)
    EVENTS = [
      :line, :class, :end, :call, :return, :c_call,
      :c_return, :raise, :b_call, :b_return,
      :thread_begin, :thread_end, :fiber_switch,
    ]

    def self.call(**args, &block)
      new(**args, &block).call
    end

    def initialize(events:[], stream: nil, filename:default_filename, &to_record)
      @events    = events
      @stream    = stream
      @filename  = filename
      @to_record = to_record
    end

    def call
      @stream ||= File.open @filename, "w"
      tp = TracePoint.new do |tp|
        next if IGNORE_FILES.include? tp.path
        log  = Log.new tp.path, tp.lineno, tp.event, tp.method_id
        dump = Marshal.dump log
        @stream.print "#{dump.bytesize}:#{dump}"
      end
      tp.enable
      @to_record.call
    ensure
      tp&.disable
      @stream&.close if @stream && !@stream.closed? && @filename
    end

    private

    def default_filename
      "#{Time.now.strftime '%F-%T'}.log"
    end
  end
end
