# -*- encoding: utf-8 -*-
require 'net/https'
require 'uri'
require 'json'

require 'pit'

require "gist_cui/version"

module GistCui
  extend self

  GIST_API_URL = 'https://api.github.com'
  GISTS_API_URL = 'https://api.github.com/gists'

  # GET /users/:user/gists
  # GET /gists
  def gists(user=nil)
    if user.nil? then
      end_point = GISTS_API_URL
    else
      end_point = "#{GIST_API_URL}/users/#{user}/gists"
    end

    d = attack(:GET, end_point)

    output(d)
    return d
  end

  # GET /gists/:id
def gist(id)
    d = attack(:GET, "#{GISTS_API_URL}/#{id}")

    output(d)
    return d
  end

  # POST /gists
  def create(file_path, desc=nil)
    file = data(file_path, desc)
    d = attack(:POST, GISTS_API_URL, auth_header, file)

    output(d)
    return d
  end

  # PATCH /gists/:id
  def edit(id, file_path, desc=nil)
    file = data(file_path, desc)
    d = attack(:PATCH, "#{GISTS_API_URL}/#{id}", auth_header, file)

    output(d)
    return d
   end

  # DELETE /gists/:id
  # success: 204 No Content
  def delete(id)
    attack(:DELETE, "#{GISTS_API_URL}/#{id}", auth_header)
  end

  def access_token()
    core = Pit.get('gist')

    client_id = core["client_id"]
    scope = 'gist'
    redirect_uri = 'http://gosyujin.github.com'

    param = { 'client_id'    => client_id, 
              'scope'        => scope, 
              'redirect_uri' => redirect_uri }
    query = param.sort.map{ |q| q.join("=") }.join("&")

    uri = "https://github.com/login/oauth/authorize?#{query}"
    puts attack(:GET2, uri)

    puts "1. Access url 2. get 'code' 3. paste 'code' this prompt and enter"
    code = STDIN.gets.chomp!
    client_secret = core["client_secret"]

    param = { 'client_id'     => client_id, 
              'client_secret' => client_secret, 
              'code'          => code }
    query = param.sort.map{ |q| q.join("=") }.join("&")

    uri = "https://github.com/login/oauth/access_token"
    puts attack(:POST2, uri, nil, query)

    puts "1. copy access_token 2. paste pit file"
  end

private
  def ca_file
    ca_path = 'lib/gist_cui/cacert.pem'
    ca_file = File.expand_path(ca_path)
    if FileTest.exist?(ca_file) then
      ca_file
    else
      puts "ca_file not found" 
      exit 1
    end
  end

  def auth_header
    core = Pit.get('gist')
    token = core["access_token"]
    { "Authorization" => "bearer " + token }
  end

  def data(files, description)
    if FileTest.exist?(File.expand_path(files)) then
      file = { File.basename(files) => 
	       { 'content' => File.read(files) }
             }

      data = {}
      data['description'] = description unless description.nil?
      data['public']      = true
      data['files']       = file
      return data
    else
      puts "#{files} not found"
      exit 1
    end
  end

  def output(data)
    json = JSON.load(data)
    if json.instance_of?(Array) then
      json.each do |j|
        puts "gist: #{j["id"]}"
        puts "user: #{j["user"]["login"]}(#{j["user"]["id"]})"
        puts "html: #{j["html_url"]}"
        puts "desc: #{j["description"]}"
        puts "---"
      end
    else
      puts "gist: #{json["id"]}"
      puts "user: #{json["user"]["login"]}(#{json["user"]["id"]})"
      puts "html: #{json["html_url"]}"
      puts "desc: #{json["description"]}"
      puts "---"
    end
  end

  def attack(method, end_point, header=nil, body=nil)
    uri = URI.parse(end_point)

    if ENV['proxy'] == "" and ENV['proxy_port'] == "" then
      #puts "not proxy"
      http = Net::HTTP.new(uri.host, uri.port)
    else
      #puts "use proxy"
      http = Net::HTTP.Proxy(ENV['proxy'], ENV['proxy_port']).new(uri.host, uri.port)
    end

    http.use_ssl = true
    http.ca_file = ca_file
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.verify_depth = 5
    
    http.start do |http|
      case method
      when :GET
        req = Net::HTTP::Get.new(uri.request_uri)
        http.request(req) do |res|
          return res.body
          # return JSON.load(res.body)
        end
      # Merge GET
      when :GET2
        req = Net::HTTP::Get.new(uri.request_uri)
        http.request(req) do |res|
          return res.body
        end
      when :POST
        req = Net::HTTP::Post.new(uri.request_uri, header)
        req.body = JSON.generate(body)
        http.request(req) do |res|
          return JSON.load(res.body)
        end
      # Merge POST
      when :POST2
        http.request_post(uri.request_uri, body) do |res|
          return res.body
        end
      when :PATCH
        req = Net::HTTP::Patch.new(uri.request_uri, header)
        req.body = JSON.generate(body)
        http.request(req) do |res|
          return JSON.load(res.body)
        end
      when :DELETE
        req = Net::HTTP::Delete.new(uri.request_uri, header)
        http.request(req) do |res|
          puts "delete #{res.code}"
          return res.code
        end
      else
        puts "else"
      end
    end
  end
end

if $0 == __FILE__ then
id = "5464265"
user = "gosyujin"

GistCui.gists
GistCui.gists(user)
GistCui.gist(id)
GistCui.edit(id, "./lib/test.txt", "dest")

# found
json = GistCui.create("./lib/test.txt", "dest")
GistCui.delete(json["id"]) # => 204

# not found
GistCui.create("./notfound.txt")
GistCui.delete("5464465") # => 404
end
