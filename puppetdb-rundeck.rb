#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'yaml'
require 'sinatra'

# Base URL of the PuppetDB database.  Do not include a trailing slash!
host_uri = 'http://localhost'
# Port number for the PuppetDB REST interface -- default is 8080 for clear, 8081 for SSL.
port = '8080'

puppetdb_resource_query = {'query'=>'["=", "type", "Class"],]'}

before do
  response["Content-Type"] = "application/yaml"
end

get '/' do
  debug   = true
  pid     = Process.pid
  uri     = URI.parse("#{host_uri}:#{port}/v3/resources")
  http    = Net::HTTP.new(uri.host, uri.port) 
  request = Net::HTTP::Get.new(uri.path) 
  request.set_form_data(puppetdb_resource_query)
  request = Net::HTTP::Get.new(uri.path+ '?' + request.body) 
  request.add_field("Accept", "application/json")
  response      = http.request(request)
  puppetdb_data = JSON.parse(response.body)

  f = File.new("/tmp/puppetdb-rundeck-#{pid}-resources", "w") if debug

  rundeck_resources = Hash.new
  puppetdb_data.each{|d|
    host  = d['certname']
    title = d['title']
    f.puts "Host: #{host} Title: #{title}" if debug
    rundeck_resources[host] = Hash.new if not rundeck_resources.key?(host)
    rundeck_resources[host]['tags'] = Array.new if not rundeck_resources[host].key?('tags')
    rundeck_resources[host]['tags'] << title
  }
  f.close if f
  
  rundeck_resources.keys.sort.each { |k|
    rundeck_resources[k]['tags'].uniq!
    rundeck_resources[k]['tags'] =  rundeck_resources[k]['tags'].join(",")
    rundeck_resources[k]['hostname'] = k
  }
  
  uri     = URI.parse("#{host_uri}:#{port}/v3/facts")
  http    = Net::HTTP.new(uri.host, uri.port) 
  request = Net::HTTP::Get.new(uri.path) 
  request = Net::HTTP::Get.new(uri.path)
  request.add_field("Accept", "application/json")
  response      = http.request(request)
  puppetdb_data = JSON.parse(response.body)
 
  f = File.new("/tmp/puppetdb-rundeck-#{pid}-facts", "w") if debug

  puppetdb_data.each{|d|
    host  = d['certname']
    next if host.nil? or host.empty?
    name  = d['name'] if d['name'] != "hostname"
    next if name.nil? or name.empty?
    value = d['value'] if d['name'] != "hostname"
    f.puts "Host: #{host} Name: #{name} Value: #{value}\n" if debug
    if ( name == 'serialnumber' )
      rundeck_resources[host][name] = 'Serial Number ' + value
    else
      rundeck_resources[host][name] = value
    end
  }
  f.close if f

  rundeck_resources.to_yaml
end
