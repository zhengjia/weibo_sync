require 'yaml'
require 'nokogiri'
require 'weibo'

configure do

  enable :sessions
  begin
    config = YAML::load File.open( './config.yml' )
    Weibo::Config.api_key = config['api_key']
    Weibo::Config.api_secret = config['api_secret']
    set :verify_token, config['verify_token']
  rescue Errno::ENOENT
    # on heroku add: heroku config:add api_key=YOUR_API_KEY api_secret=YOU_API_SECRET verify_token=YOUR_HUB_VERIFY_TOKEN
    Weibo::Config.api_key = ENV['api_key']
    Weibo::Config.api_secret = ENV['api_secret']
    set :verify_token, ENV['verify_token']
  end

  # debug feed http://search.twitter.com/search.atom?q=1
  set :topic, "http://feeds.feedburner.com/sync_to_weibo"

  set :rtoken, nil
  set :rsecret, nil

end

helpers do

  def get_oauth
    Weibo::OAuth.new(Weibo::Config.api_key, Weibo::Config.api_secret)
  end

  def update(msg)
    msg = msg[0..139]
    begin
      oauth = get_oauth
      oauth.authorize_from_access(ENV['atoken'], ENV['asecret'])
      Weibo::Base.new(oauth).update(msg)
    rescue => e
      status 401
      puts "error when updating weibo #{e.inspect}"
    end
  end

  def authenticated?
    ENV['atoken']
  end

  def parse(body)
    xml = CGI::unescape(body)
    atom = Nokogiri::XML::Document.parse xml
    entries = atom.css("entry")
    entries.collect do |entry|
      entry.css("title").text + " " + entry.css("link[rel='alternate']").first.attributes['href'].value
    end
  end

  def request_headers
    env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^x_(.*)/i; acc}
  end

end

get "/" do
  unless authenticated?
    redirect "/connect"
  end
  "connected!"
end

get '/connect' do
  if authenticated?
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
  atoken, asecret = oauth.access_token.token, oauth.access_token.secret
  puts "atoken: #{atoken}"
  puts "asecret: #{asecret}"
  # check logs and manually add the envs by heroku config:add atoken=xxx asecret=yyy
  redirect "/"
end

get "/hub_callback" do
  unless authenticated?
    status 401
  end
  if params['hub.verify_token'] == settings.verify_token && params['hub.topic'] == settings.topic
    content_type 'text/plain', :charset => 'utf-8'
    params['hub.challenge']
  else
    status 404
  end
end

post "/hub_callback" do
  puts request_headers.inspect
  tweets = parse(request.body.read)
  if authenticated?
    tweets.each do |tweet|
      update(tweet)
    end
  else
    status 401
    puts "Authentication data is lost!!!"
  end
end