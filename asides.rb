require 'rubygems'
require 'sinatra'
require 'activerecord'

configure do
  
  ActiveRecord::Base.establish_connection(
    :adapter => 'sqlite3',
    :database => 'asides.sqlite3')
  
  begin
    ActiveRecord::Schema.define do
      create_table :asides do |t|
        t.text :body, :null => false
        t.timestamps
      end
    end
  rescue ActiveRecord::StatementInvalid
    # Do nothing, since the schema already exists
  end
  
  CREDENTIALS = ['asides', 'as1d3s']
  
end

class Aside < ActiveRecord::Base
  validates_uniqueness_of :body
  
  named_scope :recent, {:limit => 10, :order => 'updated_at
DESC'}
end

helpers do

  def base_url
    if Sinatra::Application.port == 80
      "http://#{Sinatra::Application.host}/"
    else
      "http://#{Sinatra::Application.host}:#{Sinatra::Application.port}/"
    end
  end
  
  def aside_url(aside)
    "#{base_url}asides/#{aside.id}"
  end
  
  def rfc_3339(timestamp)
    timestamp.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
  
  def protected!
    auth = Rack::Auth::Basic::Request.new(request.env)
  
    # Request a username/password if the user does not send one
    unless auth.provided?
      response['WWW-Authenticate'] = %Q{Basic Realm="Shortener"}
      throw :halt, [401, 'Authorization Required']
    end
  
    # A request with non-basic auth is a bad request
    unless auth.basic?
      throw :halt, [400, 'Bad Request']
    end
  
    # Authentication is well-formed, check the credentials
    if auth.provided? && CREDENTIALS == auth.credentials
      return true
    else
      throw :halt, [403, 'Forbidden']
    end
  end
  
end

post '/asides' do
  aside = Aside.new(:body => params[:body])
  if aside.save
    status(201)
    response['Location'] = aside_url(aside)
    
    "Created aside #{aside.id} with text \"#{aside.body}\"\n"
  else
    status(412)
    
    "Error: Duplicate body\n"
  end
end

get '/asides/:id.:format' do
  aside = Aside.find(params[:id])
  case params[:format]
  when 'xml'
    content_type :xml
    aside.to_xml
  when 'json'
    content_type('application/json')
    aside.to_json
  else
    content_type :json
    aside.to_json
  end
end

put '/asides/:id' do
  aside = Aside.find(params[:id])
  aside.body = params[:body]
  if aside.save
    status(202)
    'Aside updated'
  else
    status(412)
    "Error updating aside.\n"
  end
end

delete '/asides/:id' do
  Aside.destroy(params[:id])
  status(200)
  "Deleted\n"
end

get '/asides' do
  asides = Aside.recent.all
  content_type 'application/json'
  asides.to_json
end

get '/asides.atom' do
  @asides = Aside.recent.all
  last_modified @asides.first.updated_at
  
  content_type 'application/atom+xml'
  builder do |xml|
    
    xml.instruct! :xml, :version => '1.0'
    xml.feed :'xml:lang' => 'en-US', :xmlns => 'http://www.w3.org/2005/Atom' do
      xml.id base_url
      xml.link :type => 'text/html', 
               :href => base_url, 
               :rel => 'alternate'
      xml.link :type => 'application/atom+xml', 
               :href => base_url + 'asides.atom', 
               :rel => 'self'
      xml.title 'Recently asides'
      xml.updated(rfc_3339(@asides.first ? @asides.first.updated_at : Time.now))
      @asides.each do |aside|
        xml.entry do |entry|
          entry.id aside_url(aside)
          entry.link :type => 'text/html', 
                     :href => aside_url(aside), 
                     :rel => 'alternate'
          entry.updated rfc_3339(aside.updated_at)
          entry.title aside_url(aside)
          entry.author do |author|
            author.name 'Asides'
          end
          entry.content aside.body
        end
      end
    end
    
  end
end

delete '/asides' do
  protected!
  Aside.delete_all
  status(204)
end

error ActiveRecord::RecordNotFound do
  status(404)
  @msg = "Aside not found\n"
end

not_found do
  status(404)
  @msg || "Asides doesn't know about that!\n"
end
