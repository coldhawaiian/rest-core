
require 'rest-core'

YourClient = RC::Builder.client do
  use RC::DefaultSite , 'https://api.github.com/users/'
  use RC::JsonResponse, true
  use RC::CommonLogger, method(:puts)
  use RC::Cache       , nil, 3600
end

client = YourClient.new(:cache => {})
p client.get('cardinalblue') # cache miss
puts
p client.get('cardinalblue') # cache hit

client.cache = false

puts "concurrent requests"
a = [client.get('cardinalblue'), client.get('godfat')]
puts "It's not blocking... but doing concurrent requests underneath"
p a.map{ |r| r['name'] } # here we want the values, so it blocks here
puts "DONE"

puts "callback"
client.get('cardinalblue'){ |v| p v }
puts "It's not blocking... but doing concurrent requests underneath"
client.wait # we block here to wait for the request done
puts "DONE"
