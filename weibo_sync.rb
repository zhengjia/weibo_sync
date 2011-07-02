# publisher is at http://feeds.feedburner.com/sync_to_weibo

require 'yaml'
require 'weibo'

configure do

  enable :sessions
  begin
    config = YAML::load File.open( './config.yml' )
    Weibo::Config.api_key = config['api_key']
    Weibo::Config.api_secret = config['api_secret']
  rescue Errno::ENOENT
    # on heroku add: heroku config:add api_key=YOUR_API_KEY api_secret=YOU_API_SECRET
    Weibo::Config.api_key = ENV['api_key']
    Weibo::Config.api_secret = ENV['api_secret']
  end
  set :rtoken, nil
  set :rsecret, nil
  set :atoken, nil
  set :asecret, nil

end

helpers do

  def get_oauth
    Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
  end

  def update(msg)
    oauth = get_oauth
    oauth.authorize_from_access(settings.atoken, settings.asecret)
    Weibo::Base.new(oauth).update(msg)
  end

  def parse(body)
    return [body]
  end

end

get "/" do
  unless settings.atoken
    redirect "/connect"
  end
  "connected!"
end

get '/connect' do
  if settings.atoken
    redirect "/"
  end
  request_token = get_oauth.consumer.get_request_token
  settings.rtoken, settings.rsecret = request_token.token, request_token.secret
  redirect "#{request_token.authorize_url}&oauth_callback=http://#{request.env["HTTP_HOST"]}/callback"
end

get '/callback' do
  oauth = get_oauth
  oauth.authorize_from_request(settings.rtoken, settings.rsecret, params[:oauth_verifier])
  settings.rtoken, settings.rsecret = nil, nil
  settings.atoken, settings.asecret = oauth.access_token.token, oauth.access_token.secret
  redirect "/"
end

get "/hub_callback" do
  content_type 'text/plain', :charset => 'utf-8'
  params['hub.challenge']
end

post "/hub_callback" do
  puts request.body.inspect
  tweets = parse(request.body)
  if settings.atoken
    tweets.each do |tweet|
      update(tweet)
    end
  else
    puts "Authentication data is lost!!!"
  end
end

