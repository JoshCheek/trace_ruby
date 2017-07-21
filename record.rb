def Record(*args, &block)
  Record.call(*args, &block)
end

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
      dump = Marshal.dump path: tp.path, lineno: tp.lineno, event: tp.event, method: tp.method_id
      logs.print "#{dump.bytesize}:#{dump}"
    end
    tp.enable
    yield
  ensure
    tp&.disable
    logs&.close if logs && !logs.closed?
  end

  class Rack
    attr_accessor :app, :opts

    def initialize(app, **opts)
      self.app  = app
      self.opts = opts
    end

    def call(env)
      Record(**opts) { app.call env }
    end
  end
end
