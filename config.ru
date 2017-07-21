require_relative 'app'
require_relative 'record'

use Record::Rack
run MyApp
