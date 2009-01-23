require 'rubygems'
require 'rest_client'
require 'json'

if __FILE__ == $PROGRAM_NAME
  
  json   = RestClient.get('http://localhost:4567/asides')
  asides = JSON.load(json)
  
  asides.each do |aside|
    puts "(#{aside['id']}) - #{aside['body']}"
  end
end
