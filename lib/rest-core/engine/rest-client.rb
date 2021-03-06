
require 'restclient'
require 'rest-core/patch/rest-client'

require 'rest-core/promise'
require 'rest-core/middleware'

class RestCore::RestClient
  include RestCore::Middleware
  def call env, &k
    promise = Promise.create(env, k, env[ASYNC])
    promise.gofor{ request(promise, env) }

    env[TIMER].on_timeout{
      promise.reject(env[TIMER].error)
    } if env[TIMER]

    env.merge(RESPONSE_BODY    => promise.future_body,
              RESPONSE_STATUS  => promise.future_status,
              RESPONSE_HEADERS => promise.future_headers,
              FAIL             => promise.future_failures,
              PROMISE          => promise)
  end

  def request promise, env
    payload, headers = Payload.generate_with_headers(env[REQUEST_PAYLOAD],
                                                     env[REQUEST_HEADERS])
    res = ::RestClient::Request.execute(:method   => env[REQUEST_METHOD],
                                        :url      => request_uri(env)   ,
                                        :payload  => payload            ,
                                        :headers  => headers            ,
                                        :max_redirects => 0)
    promise.fulfill(res.body, res.code, normalize_headers(res.raw_headers))

  rescue ::RestClient::Exception => e
    if res = e.response
      # we don't want to raise an exception for 404 requests
      promise.fulfill(res.body, res.code, normalize_headers(res.raw_headers))
    else
      promise.reject(e)
    end
  rescue Exception => e
    promise.reject(e)
  end

  def normalize_headers raw_headers
    raw_headers.inject({}){ |r, (k, v)|
      r[k.to_s.upcase.tr('-', '_')] = if v.kind_of?(Array) && v.size == 1
                                        v.first
                                      else
                                        v
                                      end
      r
    }
  end
end
