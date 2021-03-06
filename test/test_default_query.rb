
require 'rest-core/test'

describe RC::DefaultQuery do
  before do
    @app = RC::DefaultQuery.new(RC::Dry.new, {})
  end

  env = {RC::REQUEST_QUERY => {}}

  describe 'when given query' do
    should 'do nothing' do
      @app.call(env){ |r| r[RC::REQUEST_QUERY].should.eq({}) }
    end

    should 'merge query' do
      @app.instance_eval{@query = {'q' => 'uery'}}

      @app.call(env){ |r| r.should.eq({RC::REQUEST_QUERY => {'q' => 'uery'}}) }

      format = {'format' => 'json'}
      e      = {RC::REQUEST_QUERY => format}

      @app.call(e){ |r|
        r.should.eq({RC::REQUEST_QUERY => {'q' => 'uery'}.merge(format)}) }
    end

    should 'string_keys in query' do
      e = {'query' => {:symbol => 'value'}}
      @app.call(env.merge(e)){ |r|
        r.should.eq({RC::REQUEST_QUERY => {'symbol' => 'value'}}.merge(e))
      }
    end
  end

  describe 'when not given query' do
    should 'merge query with {}' do
      @app.call(env){ |r| r.should.eq(RC::REQUEST_QUERY => {}) }
    end
  end
end
