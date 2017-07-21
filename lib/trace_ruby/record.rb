require 'trace_ruby/log'

def Record(*args, &block)
  TraceRuby::Record.call(*args, &block)
end

module TraceRuby
  module Record
    IGNORE_FILES = []
    IGNORE_FILES << File.expand_path(__FILE__)
    EVENTS = [
      :line, :class, :end, :call, :return, :c_call,
      :c_return, :raise, :b_call, :b_return,
      :thread_begin, :thread_end, :fiber_switch,
    ]

    # When events is empty, it records all events
    def self.call(events:[], filename:"#{Time.now.strftime '%F-%T'}.log")
      logs = File.open filename, "w"
      tp = TracePoint.new *events do |tp|
        next if IGNORE_FILES.include? tp.path
        log  = Log.new tp.path, tp.lineno, tp.event, tp.method_id
        dump = Marshal.dump log
        logs.print "#{dump.bytesize}:#{dump}"
      end
      tp.enable
      yield
    ensure
      tp&.disable
      logs&.close if logs && !logs.closed?
    end
  end
end
