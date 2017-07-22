require 'trace_ruby'
require 'trace_ruby/navigator'
require 'stringio'

RSpec.describe 'Record' do
  def cursor(&b)
    stream = StringIO.new
    Record(stream: stream, &b)
    TraceRuby::FileCursor.new(StringIO.new stream.string)
  end

  it 'does not record its own code' do
    crs = cursor { "hello" }
    expect(crs.length).to be_positive
    crs.each do |event|
      expect(event.path).to include __FILE__
    end
  end

  context 'can record different events' do
    specify 'line advancement'
    specify 'class open / close'
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
