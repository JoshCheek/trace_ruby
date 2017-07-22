require 'trace_ruby'
require 'trace_ruby/navigator'
require 'stringio'

RSpec.describe 'Record' do
  def cursor(**args, &b)
    stream = StringIO.new
    Record(**args, stream: stream, &b)
    TraceRuby::FileCursor.new(StringIO.new stream.string)
  end

  it 'does not record its own code' do
    c = cursor { "hello" }
    expect(c.length).to be_positive
    c.each do |event|
      expect(event.path).to include __FILE__
    end
  end

  context 'records different types of events, recording by defualt, but toggleable' do
    def assert_toggleable(type, &b)
      # toggled on
      assertions = []
      c = cursor(type => true) { b.call assertions }
      seen = c.select { |e| e.is? type }
      assertions.each do |assertion|
        expect(seen.find &assertion).to_not be_nil
      end

      # toggled off
      c = cursor(type => false) { b.call [] }
      expect(c.count { |e| e.is? type }).to eq 0

      # default
      c = cursor { b.call [] }
      expect(c.count { |e| e.is? type }).to eq seen.length
    end

    specify 'line advancement' do
      assert_toggleable :lines do |assertions|
        assertions << -> e { e.lineno = __LINE__ }
        assertions << -> e { e.lineno = __LINE__ }
      end
    end

    specify 'class and module open / close' do
      assert_toggleable :modules do |assertions|
        class Object
        end
        module Comparable
        end
        lines = {open1: __LINE__-4, close1: __LINE__-3, open2: __LINE__-2, close2: __LINE__-1 }
        lines.each do |name, lineno|
          if /open/=~name
            assertions << -> e { e.lineno == lineno && e.open? && !e.close? }
          else
            assertions << -> e { e.lineno == lineno && !e.open? && e.close? }
          end
        end
      end
    end

    specify 'method call / return (Ruby and C)'
    specify 'block call / return'
    specify 'thread beginning and ending'
    specify 'switching fibers'
    specify 'by default it logs all of these'
  end

  describe 'logging' do
    specify 'by defualt it logs to a file with the current date/time'
    it 'can be given a custom logfilename'
    it 'can be given a stream to log to'
  end
end
