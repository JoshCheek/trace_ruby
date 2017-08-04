require 'trace_ruby/record'

module TraceRuby
  class Rack
    attr_accessor :app, :opts
    def initialize(app, **opts)
      self.app  = app
      self.opts = opts
    end
    def call(env)
      TraceRuby::Record(**opts) { app.call env }
    end
  end
end
