module TraceRuby
  Log = Struct.new :path, :lineno, :event, :method do
    alias to_hash to_h
    alias fetch []
  end
end
