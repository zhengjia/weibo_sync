desc "This task is called by the Heroku cron add-on"
task :cron do
  `wget -qO- http://feeds.feedburner.com/sync_to_weibo`
end