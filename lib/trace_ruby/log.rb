module TraceRuby
  Log = Struct.new :path, :lineno, :event, :method do
    alias to_hash to_h
    alias fetch []
    def is?(type)
      case type
      when :lines   then event == :line
      when :modules then event == :class || event == :end
      else
        raise "Invalid type: #{type.inspect}"
      end
    end

    def open?
      event == :class
    end

    def close?
      event == :end
    end
  end
end
