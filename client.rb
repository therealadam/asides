require 'optparse'

require 'rubygems'
require 'rest_client'
require 'json'

class AsideClient
  def self.run!(args)
    options = {:host => 'localhost', :port => 4567}
    OptionParser.new do |opts|
      opts.banner = "Usage: asides [options] COMMAND <entry ID> (entry text)"
      
      opts.on('-h', '--host HOSTNAME', 'Host') do |host|
        options[:host] = host
      end
      
      opts.on('-p', '--port PORT', 'Port') do |port|
        options[:port] = port
      end
    end.parse!(args)
    
    cmd = args.shift
    cmd_args = args
    
    client = new(options[:host], options[:port])
    client.run_command_with_args(cmd, cmd_args)
  end
  
  attr_reader :host, :port
  
  def initialize(host, port)
    @host = host
    @port = port
  end
  
  def run_command_with_args(name, args)
    case name
    when 'save'
      save(*args)
    when 'list'
      list(*args)
    when 'fetch'
      fetch(*args)
    when 'delete'
      delete(*args)
    else
      raise "Unimplemented command: #{name}"
    # when 'update'
    end
  end
  
  private
  
    def client
      @client ||= RestClient::Resource.new("http://#{host}:#{port}")
    end
  
  module Commands
    
    def save(text)
      resp = client['/asides'].post(:body => text)
      puts resp
    rescue RestClient::RequestFailed => e
      case e.http_code
      when 412
        puts e.response.body
      else
        "HTTP Error: #{e.message}"
      end
    end
    
    def list
      json = client['/asides'].get
      asides = JSON.load(json)
      
      display asides
    end
    
    def fetch(aside)
      display JSON.load(client["/asides/#{Integer(aside)}.json"].get)
    end
    
    def delete(aside)
      client["/asides/#{Integer(aside)}"].delete
      puts "Deleted aside."
    end
    
  end
  
  module Helpers
    
    def display(asides)
      printer = lambda { |a| puts "ID: #{a['id']} - #{a['body']}" }
      case asides
      when Array
        asides.each { |a| printer.call(a) }
      when Hash
        printer.call(asides)
      end
    end
    
  end
  
  include Commands
  include Helpers
  
end

AsideClient.run!(ARGV)