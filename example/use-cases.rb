
require 'fiber'
require 'em-http-request'
require 'rest-core'
RC.eagerload

def def_use_case name, &block
  singleton_class.send(:define_method, "#{name}_", &block)
  singleton_class.send(:define_method, name) do
    @count ||= 0
    printf "Use case #%02d: %s\n", @count+=1, name
    puts '-' * 70
    start = Time.now
    send("#{name}_")
    puts "Spent #{Time.now - start} seconds for this use case."
    puts
  end
end

def q str, m=nil
  p = lambda{ puts "\e[33m=> #{str.inspect}\e[0m" }
  if m
    m.synchronize(&p)
  else
    p.call
  end
end

# ----------------------------------------------------------------------

def_use_case 'pure_ruby_single_request' do
  q RC::Universal.new(:json_response => true).
    get('https://graph.facebook.com/4')['name']
end

def_use_case 'pure_ruby_concurrent_requests' do
  client = RC::Universal.new(:json_response => true,
                             :site => 'https://graph.facebook.com/')
  q [client.get('4'), client.get('5')].map{ |u| u['name'] }
end

def_use_case 'pure_ruby_cache_requests' do
  client = RC::Universal.new(:json_response => true, :cache => {})
  3.times{ q client.get('https://graph.facebook.com/4')['name'] }
end

def_use_case 'pure_ruby_callback_requests' do
  m = Mutex.new
  RC::Universal.new(:json_response => true                                  ,
                    :site          => 'https://graph.facebook.com/'         ,
                    :log_method    => lambda{|str| m.synchronize{puts(str)}}).
    get('4'){ |res|
      q res['name'], m
    }.
    get('5'){ |res|
      q res['name'], m
    }.wait
end

def_use_case 'pure_ruby_nested_concurrent_requests' do
  m = Mutex.new
  c = RC::Universal.new(:json_response => true                              ,
                        :site          => 'https://graph.facebook.com/'     ,
                        :log_method => lambda{|str| m.synchronize{puts(str)}})

  %w[4 5].each{ |user|
    c.get(user, :fields => 'cover'){ |data|
      cover    = data['cover']
      comments = c.get("#{cover['id']}/comments")
      likes    = c.get("#{cover['id']}/likes")
      most_liked_comment = comments['data'].max_by{|d|d['like_count']}

      q "Author of most liked comment from #{user}'s cover photo:", m
      q most_liked_comment['from']['name'], m

      y = !!likes['data'].find{|d|d['id'] == most_liked_comment['from']['id']}
      q "Did the user also like the cover?: #{y}", m
    }
  }

  c.wait
end

# ----------------------------------------------------------------------

def_use_case 'eventmachine_fiber_single_request'             do
  EM.run{  Fiber.new{ pure_ruby_single_request_            ; EM.stop }.resume}
end

def_use_case 'eventmachine_fiber_concurrent_requests'        do
  EM.run{  Fiber.new{ pure_ruby_concurrent_requests_       ; EM.stop }.resume}
end

def_use_case 'eventmachine_fiber_cache_requests'             do
  EM.run{  Fiber.new{ pure_ruby_cache_requests_            ; EM.stop }.resume}
end

def_use_case 'eventmachine_fiber_callback_requests'          do
  EM.run{  Fiber.new{ pure_ruby_callback_requests_         ; EM.stop }.resume}
end

def_use_case 'eventmachine_fiber_nested_concurrent_requests' do
  EM.run{  Fiber.new{ pure_ruby_nested_concurrent_requests_; EM.stop }.resume}
end

# ----------------------------------------------------------------------

def_use_case 'eventmachine_thread_single_request'             do
  EM.run{ Thread.new{ pure_ruby_single_request_            ; EM.stop } }
end

def_use_case 'eventmachine_thread_concurrent_requests'        do
  EM.run{ Thread.new{ pure_ruby_concurrent_requests_       ; EM.stop } }
end

def_use_case 'eventmachine_thread_cache_requests'             do
  EM.run{ Thread.new{ pure_ruby_cache_requests_            ; EM.stop } }
end

def_use_case 'eventmachine_thread_callback_requests'          do
  EM.run{ Thread.new{ pure_ruby_callback_requests_         ; EM.stop } }
end

def_use_case 'eventmachine_thread_nested_concurrent_requests' do
  EM.run{ Thread.new{ pure_ruby_nested_concurrent_requests_; EM.stop } }
end

# ----------------------------------------------------------------------

def_use_case 'eventmachine_rest_client_single_request'        do
  EM.run{             pure_ruby_single_request_            ; EM.stop   }
end

def_use_case 'eventmachine_rest_client_concurrent_requests'   do
  EM.run{             pure_ruby_concurrent_requests_       ; EM.stop   }
end

def_use_case 'eventmachine_rest_client_cache_requests'        do
  EM.run{             pure_ruby_cache_requests_            ; EM.stop   }
end

def_use_case 'eventmachine_rest_client_callback_requests'     do
  EM.run{             pure_ruby_callback_requests_         ; EM.stop   }
end

def_use_case 'eventmachine_rest_client_nested_concurrent_requests' do
  EM.run{             pure_ruby_nested_concurrent_requests_; EM.stop   }
end

# ----------------------------------------------------------------------

def_use_case 'pure_ruby' do
  pure_ruby_single_request
  pure_ruby_concurrent_requests
  pure_ruby_cache_requests
  pure_ruby_callback_requests
  pure_ruby_nested_concurrent_requests
end

def_use_case 'eventmachine_fiber' do
  eventmachine_fiber_single_request
  eventmachine_fiber_concurrent_requests
  eventmachine_fiber_cache_requests
  eventmachine_fiber_callback_requests
  eventmachine_fiber_nested_concurrent_requests
end

def_use_case 'eventmachine_thread' do
  eventmachine_thread_single_request
  eventmachine_thread_concurrent_requests
  eventmachine_thread_cache_requests
  eventmachine_thread_callback_requests
  eventmachine_thread_nested_concurrent_requests
end

def_use_case 'eventmachine_rest_client' do
  eventmachine_rest_client_single_request
  eventmachine_rest_client_concurrent_requests
  eventmachine_rest_client_cache_requests
  eventmachine_rest_client_callback_requests
  eventmachine_rest_client_nested_concurrent_requests
end

# ----------------------------------------------------------------------

pure_ruby
eventmachine_fiber
eventmachine_thread
eventmachine_rest_client
