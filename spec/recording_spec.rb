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
        assertions << -> e { e.lineno == __LINE__ }
        assertions << -> e { e.lineno == __LINE__ }
      end
    end

    specify 'class and module open / close' do
      assert_toggleable :modules do |assertions|
        class Object
        end
        module Comparable
        end
        lines = { __LINE__-4 => __LINE__-3, __LINE__-2 => __LINE__-1 }
        lines.each do |beginno, endno|
          assertions << -> e { e.lineno == beginno &&  e.begin? && !e.end? }
          assertions << -> e { e.lineno == endno   && !e.begin? &&  e.end? }
        end
      end
    end

    ruby_line = __LINE__; def a_method; end
    specify 'method call / return (Ruby and C)' do
      assert_toggleable :methods do |assertions|
        c_line = __LINE__; Object.new
        a_method
        assertions << -> e { e.lineno == c_line    &&  e.begin? && !e.end? && e.method == :new }
        assertions << -> e { e.lineno == c_line    && !e.begin? &&  e.end? && e.method == :new }
        assertions << -> e { e.lineno == ruby_line &&  e.begin? && !e.end? && e.method == :a_method }
        assertions << -> e { e.lineno == ruby_line && !e.begin? &&  e.end? && e.method == :a_method }
      end
    end

    specify 'block call / return' do
      assert_toggleable :blocks do |assertions|
        lambda do
        end.call
        beginno, endno = __LINE__-2, __LINE__-1
        assertions << -> e { e.lineno == beginno &&  e.begin? && !e.end? }
        assertions << -> e { e.lineno == endno   && !e.begin? &&  e.end? }
      end
    end

    specify 'error raising' # :raise
    specify 'thread beginning and ending' # :thread_begin, :thread_end
    specify 'switching fibers' # :fiber_switch
  end

  describe 'logging' do
    def get_logs
      Dir['*.log']
    end

    around :each do |spec|
      Dir.chdir __dir__ do
        get_logs.each { |filename| File.delete filename }
        spec.call
      end
    end

    specify 'by defualt it logs to a file in the current dir with the current date/time' do
      time = Time.now
      Record { }
      logs = get_logs
      expect(logs.length).to eq 1
      logtime = Time.new(*logs.first.scan(/\d+/).map(&:to_i))
      expect(logtime).to be_within(1).of(time)
    end

    it 'can be given a custom logfilename' do
      Record(filename: 'lol.log') { }
      expect(get_logs).to eq ['lol.log']
    end

    it 'can be given a stream to log to' do
      stream = StringIO.new
      Record(stream: stream) { }
      expect(get_logs).to be_empty
      expect(stream.string).to_not be_empty
    end
  end
end
