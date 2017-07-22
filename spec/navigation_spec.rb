require 'trace_ruby'
require 'trace_ruby/navigator'

RSpec.describe 'Navigator allows for more sophisticated traversal over a stream' do
  include TraceRuby

  def record(only: nil, &b)
    args = {lines: true, modules: true, methods: true, blocks: true}
    if only
      args.each { |k, _| args[k] = false }
      args[only] = true
    end
    stream = StringIO.new
    Record(**args, stream: stream, &b)
    TraceRuby::Navigator.from_stream(StringIO.new stream.string)
  end

  def three_lines
    lines = []
    nav = record only: :lines do
      lines << __LINE__
      lines << __LINE__
      lines << __LINE__
    end
    return lines, nav
  end

  def assert_crnt(nav, assertion)
    crnt = nav.crnt
    case assertion
    when Integer then expect(crnt.lineno).to eq(assertion)
    else raise "Unimplemented assertion: #{assertion.inspect}"
    end
  rescue RSpec::Expectations::ExpectationNotMetError
    $!.set_backtrace caller.drop 1
    raise
  end

  it 'knows the current event' do
    lines, nav = three_lines
    assert_crnt nav, lines[0]
    nav.next
    assert_crnt nav, lines[1]
    nav.next
    assert_crnt nav, lines[2]
  end

  it 'can jump to the first, last, and numbered events' do
    lines, nav = three_lines
    assert_crnt nav.to_first,    lines[0]
    assert_crnt nav.to_last,     lines[2]
    assert_crnt nav.to_first,    lines[0]
    assert_crnt nav.to_index(0), lines[0]
    assert_crnt nav.to_index(1), lines[1]
    assert_crnt nav.to_index(2), lines[2]
  end

  describe 'general tree traversal' do
    def two_calls
      methods = []
      nav = record only: :methods do
        m2 methods
        m2 methods
      end
      return methods, nav
    end

    def three_deep
      methods = []
      nav = record do
        m3 methods
      end
      return methods, nav
    end

    def m3(methods)
      methods << [:call,   :m3, __LINE__-1]
      m2 methods
      methods << [:return, :m3, __LINE__+1]
    end
    def m2(methods)
      methods << [:call,   :m2, __LINE__-1]
      m1 methods
      methods << [:return, :m2, __LINE__+1]
    end
    def m1(methods)
      methods << [:call,   :m1, __LINE__-1]
      methods << [:return, :m1, __LINE__+1]
    end

    it 'can go into and out of method calls'
    it 'can go into and out of block calls'
    it 'can go into and out of class definitions'
    it 'can go up and down lines'
    it 'can\'t go out of the root'
    it 'can\'t go in from a leaf'
    it 'can\'t go up from from the first line in a method call'
    it 'can\'t go down from the last line in a method call'

    it 'can do prefix traversal (execution order)' do
      methods, nav = two_calls
      actuals = nav.prefix_each.map { |e| [e.event, e.method, e.lineno] }
      expect(methods).to eq actuals
    end

  end

  # search forward
  # search backward
  # skip forward
  # filter out a file
  # filter out a directory tree
  # select a directory tree
end
