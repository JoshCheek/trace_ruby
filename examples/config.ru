require 'trace_ruby/rack'
require_relative 'app'

use TraceRuby::Rack
run MyApp
