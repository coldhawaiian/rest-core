
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

puts "callback"
client.get('cardinalblue'){ |v| p v }.wait

puts "future"
v = client.get('cardinalblue', {}, :cache => false)
puts "non-blocking"
p v # block here since we're asking the value of it
puts "done"