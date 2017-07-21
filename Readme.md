Records a Ruby execution path and plays it back.

Example recording:

```sh
# A simple one-file example
$ ruby plain_ruby_example.rb

# See how Sinatra handles a get request
$ rackup config.ru
# now make a request to the root and then kill it
```

Example playback:

```sh
$ ruby play.rb
```
