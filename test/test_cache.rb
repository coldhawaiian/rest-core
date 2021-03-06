
require 'rest-core/test'

describe RC::Cache do
  after do
    WebMock.reset!
    Muack.verify
  end

  should 'basic 0' do
    c = RC::Builder.client do
      use RC::Cache, {}, 3600
      run Class.new{
        attr_accessor :tick
        def initialize
          self.tick = 0
        end
        def call env
          self.tick +=1
          yield(env.merge(RC::RESPONSE_BODY    => 'response',
                          RC::RESPONSE_HEADERS => {'A' => 'B'},
                          RC::RESPONSE_STATUS  => 200))
        end
      }
    end.new
    c.get('/')
    key = Digest::MD5.hexdigest('get:/:')
    c.cache.should.eq("rest-core:cache:#{key}" => "200\nA: B\n\n\nresponse")
    c.app.app.tick.should.eq 1
    c.get('/')
    c.app.app.tick.should.eq 1
    c.cache.clear
    c.get('/')
    c.app.app.tick.should.eq 2
    c.head('/').should.eq('A' => 'B')
    c.get('/').should.eq 'response'
    c.request({RC::REQUEST_PATH => '/'}, RC::RESPONSE_STATUS).should.eq 200
  end

  should 'basic 1' do
    path = 'http://a'
    stub_request(:get , path).to_return(:body => 'OK')
    stub_request(:post, path).to_return(:body => 'OK')
    c = RC::Builder.client do
      use RC::Cache, nil, nil
    end

    c.new                  . get(path).should.eq('OK')
    c.new(:cache => (h={})).post(path).should.eq('OK')
    h.should.eq({})
    c.new(:cache => (h={})). get(path).should.eq('OK')
    h.size.should.eq 1
    c.new(:cache => (h={})). get(path, {}, :cache => false).should.eq('OK')
    h.should.eq({})
    c.new                  . get(path, {}, 'cache.update' => true).
                                                            should.eq('OK')
  end

  should 'not raise error if headers is nil' do
    path = 'http://a'
    stub_request(:get , path).to_return(:body => 'OK', :headers => nil)
    c = RC::Builder.client do
      use RC::Cache, {}, nil
    end.new
    c.get(path).should.eq 'OK'
    c.get(path).should.eq 'OK'
  end

  should 'head then get' do
    c = RC::Builder.client do
      use RC::Cache, {}, nil
    end.new
    path = 'http://example.com'
    stub_request(:head, path).to_return(:headers => {'A' => 'B'})
    c.head(path).should.eq('A' => 'B')
    stub_request(:get , path).to_return(:body => 'body')
    c.get(path).should.eq('body')
  end

  should 'only [] and []= should be implemented' do
    cache = Class.new do
      def initialize    ; @h = {}                      ; end
      def []  key       ; @h[key]                      ; end
      def []= key, value; @h[key] = value.sub('4', '5'); end
    end.new
    c = RC::Builder.client do
      use RC::Cache, cache, 0
      run Class.new{
        def call env
          yield(env.merge(RC::RESPONSE_BODY   => env[RC::REQUEST_PATH],
                          RC::RESPONSE_STATUS => 200))
        end
      }
    end.new
    c.get('4')
    c.get('4').should.eq '5'
  end

  should 'cache the original response' do
    c = RC::Builder.client do
      use RC::Cache, {}, 3600 do
        use RC::JsonResponse, true
      end
    end.new
    stub_request(:get, 'me').to_return(:body => body = '{"a":"b"}')
    c.get('me').should.eq 'a' => 'b'
    c.cache.values.first.should.eq "200\n\n\n#{body}"
  end

  should 'multiline response' do
    c = RC::Builder.client do
      use RC::Cache, {}, 3600
    end.new
    stub_request(:get, 'html').to_return(:body => body = "a\n\nb")
    c.get('html').should.eq body
    c.cache.values.first.should.eq "200\n\n\n#{body}"
    c.get('html')       .should.eq body
  end

  should "follow redirect with cache.update correctly" do
    c = RC::Builder.client do
      use RC::FollowRedirect, 10
      use RC::Cache, {}, nil
    end.new
    x, y, z = 'http://X', 'http://Y', 'http://Z'
    stub_request(:get, x).to_return(:headers => {'Location' => y},
                                    :status  => 301)
    stub_request(:get, y).to_return(:headers => {'Location' => z},
                                    :status  => 302)
    stub_request(:get, z).to_return(:body => 'OK')
    c.get(x, {}, 'cache.update' => true).should.eq 'OK'
  end

  should 'not cache post/put/delete' do
    [:put, :post, :delete].each{ |meth|
      url, body = "https://cache", 'ok'
      stub_request(meth, url).to_return(:body => body).times(3)

      cache = {}
      c = RC::Builder.client{use RC::Cache, cache, nil}.new
      3.times{
        if meth == :delete
          c.send(meth, url).should.eq(body)
        else
          c.send(meth, url, 'payload').should.eq(body)
        end
      }
      cache.should.eq({})
    }
  end

  should 'not cache dry run' do
    c = RC::Builder.client{use RC::Cache, {}, nil}.new
    c.url('test')
    c.cache.should.eq({})
  end

  should 'update cache if there is cache option set to false' do
    url, body = "https://cache", 'ok'
    stub_request(:get, url).to_return(:body => body)
    c = RC::Builder.client{use RC::Cache, {}, nil}.new

    c.get(url)                            .should.eq body
    stub_request(:get, url).to_return(:body => body.reverse).times(2)
    c.get(url)                            .should.eq body
    c.get(url, {}, 'cache.update' => true).should.eq body.reverse
    c.get(url)                            .should.eq body.reverse
    c.cache = nil
    c.get(url, {}, 'cache.update' => true).should.eq body.reverse
  end

  describe 'expires_in' do
    before do
      @url, @body = "https://cache", 'ok'
      stub_request(:get, @url).to_return(:body => @body)
      @cache = {}
      mock(@cache).method(:store){ mock.arity{ -3 }.object }
      mock(@cache).store(is_a(String), is_a(String), :expires_in => 3){}
      @cache
    end

    should 'respect in options' do
      c = RC::Builder.client{use RC::Cache, nil, nil}.new
      c.get(@url, {}, :cache => @cache, :expires_in => 3).should.eq @body
    end

    should 'respect in middleware' do
      c = RC::Builder.client{use RC::Cache, nil,   3}.new(:cache => @cache)
      c.get(@url).should.eq @body
    end
  end
end
