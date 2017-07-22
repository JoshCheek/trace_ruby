require 'trace_ruby/log'

def Record(*args, &block)
  TraceRuby::Record.call(*args, &block)
end

module TraceRuby
  class Record
    IGNORE_FILES = [File.expand_path(__FILE__)]

    def self.call(*args, &block)
      new(*args, &block).call
    end

    def initialize(
      events:   [],
      stream:   nil,
      filename: default_filename,
      lines:    true,
      modules:  true,
      methods:  true,
      blocks:   true,
      &to_record
    )
      @events      = events
      @stream      = stream
      @filename    = filename
      @to_record   = to_record
      @event_names = []
      lines   and @event_names << :line
      modules and @event_names << :class << :end
      methods and @event_names << :call << :return << :c_call << :c_return
      blocks  and @event_names << :b_call << :b_return
    end

    def call
      @stream ||= File.open @filename, "w"
      tp = TracePoint.new *@event_names do |tp|
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
