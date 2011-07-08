A ruby example of using pubsubhubbub (http://pubsubhubbub.appspot.com) to sync my github activity feed to a twitter like service in china http://weibo.com/2211540520.

The github activity feed is republished to http://feeds.feedburner.com/sync_to_weibo and is pubsubhubbub compatible. It looks like if your feedburner feed doesn't have any subscriber then the feed won't update itself. I used a pingdom free account to ping the feed at 1 minute interval.

The subscriber is the sinatra app in this repo and is available at http://simple-lightning-771.heroku.com/