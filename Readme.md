Trace Ruby
==========

Records a Ruby execution path and plays it back.

Record the examples:

```sh
# A simple one-file example
$ ruby -I lib examples/plain_ruby_example.rb

# See how Sinatra handles a get request
$ rackup -I lib examples/config.ru # now make a request to the root and then kill it
```

Play the logs back

```sh
$ ruby bin/play              # most recent log
$ ruby bin/play whatever.log # some specific log
```

Adding your own recording:

```ruby
require 'trace_ruby/record'
Record { puts "your code here!" }
```
