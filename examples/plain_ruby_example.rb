require 'trace_ruby/record'
Record do
  class A
    def square(a)
      return a*a
    end
  end

  a = A.new
  a.square(5)
end
