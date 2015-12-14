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
  prediction = PunditBot.generate_prediction
  tweet = client.update(prediction.prediction_text)
  exhortation_tweet = client.update(prediction.exhortation + " #{tweet.url}")
  # a quoted tweet just appends at the end the link https://dev.twitter.com/rest/reference/post/statuses/update
end