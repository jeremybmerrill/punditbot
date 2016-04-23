require_relative "./punditbot.rb"
require 'twitter'
if __FILE__ == $0
  creds = YAML.load_file("creds.yml")
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = creds["consumer_key"]
    config.consumer_secret     = creds["consumer_secret"]
    config.access_token        = creds["access_token"]
    config.access_token_secret = creds["access_token_secret"]
  end
  while 1
    prediction = PunditBot.generate_prediction
    break unless prediction.nil? || prediction.to_s.nil?
  end
  
  if prediction.to_s.size > 140 && prediction.to_s[-1] == "."
    prediction.to_s = prediction.to_s[0...-1]
  end

  puts "trying to tweet `#{prediction.to_s}` (an attempt to solve the occasional missing status error from the Twitter gem.)"
  tweet = client.update(prediction.to_s)
  # exhortation_tweet = client.update(prediction.exhortation + " #{tweet.url}")
  # a quoted tweet just appends at the end the link https://dev.twitter.com/rest/reference/post/statuses/update
end