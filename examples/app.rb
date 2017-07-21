require 'sinatra/base'

class MyApp < Sinatra::Base
  get '/' do
    '<h1>Helloooo!</h1>'
  end
end
