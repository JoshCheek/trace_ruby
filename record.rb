require 'json'

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

  def self.call(events:EVENTS, filename:"#{Time.now.strftime '%F-%T'}.log")
    log = File.open filename, "w"
    events = []
    tp = TracePoint.new *events do |tp|
      next if IGNORE_FILES.include? tp.path
      log.puts({path: tp.path, lineno: tp.lineno, event: tp.event, method: tp.method_id}.to_json)
    end
    tp.enable
    yield
  ensure
    tp&.disable
    log&.close if log && !log.closed?
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
