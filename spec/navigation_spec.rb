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
    $!.set_backtrace caller.drop(1)
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

  it 'can do depth-first traversal (execution order)'
  describe 'general tree traversal' do
    it 'can go into and out of method calls'
    it 'can go into and out of block calls'
    it 'can go into and out of class definitions'
    it 'can go up and down lines'
    it 'can\'t go out of the root'
    it 'can\'t go in from a leaf'
    it 'can\'t go up from from the first line in a method call'
    it 'can\'t go down from the last line in a method call'
  end

  # search forward
  # search backward
  # skip forward
  # filter out a file
  # filter out a directory tree
  # select a directory tree
end
