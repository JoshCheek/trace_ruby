module TraceRuby
  Log = Struct.new :path, :lineno, :event, :method do
    alias to_hash to_h
    alias fetch []
    def is?(type)
      case type
      when :lines   then event == :line
      when :modules then event == :class || event == :end
      when :methods then event == :call || event == :return || event == :c_call || event == :c_return
      when :blocks  then event == :b_call || event == :b_return
      else
        raise "Invalid type: #{type.inspect}"
      end
    end

    def begin?
      event == :class || event == :call || event == :c_call || event == :b_call
    end

    def end?
      event == :end || event == :return || event == :c_return || event == :b_return
    end
  end
end
