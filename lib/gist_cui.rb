# -*- encoding: utf-8 -*-
require 'net/https'
require 'uri'
require 'json'

require 'thor'
require 'pit'

require "gist_cui/version"

module GistCui
  class CLI < Thor
    class_option :help, aliases: "-h", type: :boolean, desc: "gist_cui help"

    GH_API_URL  = 'https://api.github.com'
    GISTS_API_URL = 'https://api.github.com/gists'

    @user = ""
    @repository = ""

    # GET /repos/:user/:repository/:number
    desc "issues",
         "get issues(DEFAULT: all issues current repository from github)"
    method_option :user  , aliases: "-u", type: :string ,
                  desc: "github user(DEFAULT: origin user)"
    method_option :repo  , aliases: "-r", type: :string ,
                  desc: "user's repository(DEFAULT: origin repository)"
    method_option :num   , aliases: "-n", type: :string ,
                  desc: "a issue number"
    method_option :closed, aliases: "-c", type: :boolean,
                  desc: "get CLOSED issue"
    def issue
      repos = current_repos_and_user

      user   = options[:user].nil? ? repos["user"] : options[:user]
      repo   = options[:repo].nil? ? repos["repo"] : options[:repo]
      number = options[:num].nil?  ? nil           : "#{options[:num]}"
      state  = options[:closed]    ? "closed"      : "open"

      end_point = "#{GH_API_URL}/repos/#{user}/#{repo}/issues"
      end_point += "/#{number}" unless number.nil?
      end_point += "?state=#{state}"

      issues = request(:GET, end_point)

      JSON.load(issues).each do |i|
        puts "No.#{i["number"]} #{i["state"]} (#{i["user"]["login"]}): #{i["title"]}"
        puts "--"
        puts "#{i["body"]}" unless i["body"] == ""
        unless i["comments"] == 0 then
          JSON.load(issue_comments(user, repo, i["number"])).each do |c|
            puts ">>>>>>>>>>>>>>>>>>>>>>"
            puts "> #{c["user"]["login"]}"
            puts "#{c["body"]}"
          end
        end
        puts "==================================================================="
      end
    end

    # POST /repos/:owner/:repo/issues
    desc "create",
         "create issue"
    def create
      repos = current_repos_and_user

      user   = options[:user].nil? ? repos["user"] : options[:user]
      repo   = options[:repo].nil? ? repos["repo"] : options[:repo]

      end_point = "#{GH_API_URL}/repos/#{user}/#{repo}/issues"
      data = {}

      data['title'] = "hohogeri"

      issue = request(:POST, end_point, auth_header, data)
      issue = JSON.load(issue)
      puts "#{issue["title"]} #{issue["url"]}"
    end

    # GET /users/:user/gists
    # GET /gists
    # GET /gists/:id
    desc "get [-u USER|-i GIST_ID|-p]",
         "get [my|public] gists or selected a gist(DEFAULT: public gists)\n" \
         "option priorities: -u > -i > -p"
    method_option :user  , aliases: "-u", type: :string , desc: "select gists by user"
    method_option :id    , aliases: "-i", type: :string , desc: "select id's gist"
    method_option :public, aliases: "-p", type: :boolean, desc: "select public gists"
    def get
      if options.key?("user") then
        user = options["user"]
        end_point = "#{GH_API_URL}/users/#{user}/gists"
      elsif options.key?("id") then
        id = options["id"]
        end_point = "#{GISTS_API_URL}/#{id}"
      else
        end_point = GISTS_API_URL
      end

      d = request(:GET, end_point)
      output d
    end

    # POST /gists
    desc "add [ADD_FILE] [-d]",
         "add new gist"
    method_option :description, aliases: "-d", type: :string, desc: "add description"
    def add(file)
      file = data(file, options["description"])
      d = request(:POST, GISTS_API_URL, auth_header, file)

      output d
    end

    # PATCH /gists/:id
    desc "edit [GIST_ID] [EDIT_FILE] [-d]",
         "edit gist (REQUIRE: more than Ruby 1.9.3)"
    method_option :description, aliases: "-d", type: :string, desc: "edit description"
    def edit(id, file)
      file = data(file, options["description"])
      d = request(:PATCH, "#{GISTS_API_URL}/#{id}", auth_header, file)

      output d
    end

    # DELETE /gists/:id
    # success: 204 No Content
    desc "delete [GIST_ID] [GIST_ID] ...",
         "delete gists (SPLIT space " ")"
    def delete(*gist_ids)
      gist_ids.each do |id|
        request(:DELETE, "#{GISTS_API_URL}/#{id}", auth_header)
      end
    end

    # get access_token
    desc "init",
         "get access_token"
    def init
      access_token
    end

  private
    def current_repos_and_user
      repos = {}

      remote = `git remote -v`
      remote.match(/github\.com[\/:](.*)\.git/)
      repos["user"], repos["repo"] = $1.split("/")
      #puts "current user: #{repos["user"]}"
      #puts "current repo: #{repos["repo"]}"
      repos
    end

    # GET /repos/:owner/:repo/issues/:number/comments
    def issue_comments(owner, repo, number)
      end_point = "#{GH_API_URL}/repos/#{owner}/#{repo}/issues/#{number}/comments"
      request(:GET, end_point)
    end

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

    def data(files, description=nil)
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
        puts "File: #{files} not found"
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

    def request(method, end_point, header=nil, body=nil)
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
          end
        when :POST
          req = Net::HTTP::Post.new(uri.request_uri, header)
          req.body = JSON.generate(body)
          http.request(req) do |res|
            return res.body
          end
        # Merge POST
        when :POST2
          http.request_post(uri.request_uri, body) do |res|
            return res.body
          end
        when :PATCH
          if RUBY_VERSION == "1.9.2" or RUBY_VERSION.to_f <= 1.8 then
            puts "edit is required ruby more than 1.9.3"
            exit 1
          end
          req = Net::HTTP::Patch.new(uri.request_uri, header)
          req.body = JSON.generate(body)
          http.request(req) do |res|
            return res.body
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

    def access_token()
      core = Pit.get('gist')

      client_id = core["client_id"]
      # FIXME: choose scope
      scope = 'gist,user,repo'
      redirect_uri = 'http://gosyujin.github.com'

      param = { 'client_id'    => client_id,
                'scope'        => scope,
        'redirect_uri' => redirect_uri }
      query = param.sort.map{ |q| q.join("=") }.join("&")

      uri = "https://github.com/login/oauth/authorize?#{query}"
      puts request(:GET, uri)

      puts "1. Access url 2. get 'code' 3. paste 'code' this prompt and enter"
      code = STDIN.gets.chomp!
      client_secret = core["client_secret"]

      param = { 'client_id'     => client_id,
              'client_secret' => client_secret,
        'code'          => code }
      query = param.sort.map{ |q| q.join("=") }.join("&")

      uri = "https://github.com/login/oauth/access_token"
      puts request(:POST2, uri, nil, query)

      puts "1. copy access_token 2. paste pit file"
    end

  end
end

if $0 == __FILE__ then
  id = "5472739"
  user = "gosyujin"

  puts "#### show gists"
  GistCui.gists
  puts "#### show #{user}'s gists"
  GistCui.gists(user)
  puts "#### show #{id}'s gist"
  GistCui.gist(id)
  puts "#### edit gist"
  GistCui.edit(id, "./hoge.txt", "dest")

  puts "#### create and delete gist"
  json = GistCui.create("./hoge.txt", "dest")
  GistCui.delete(json["id"]) # => 204

  puts "#### not found gist"
  GistCui.create("./notfound.txt")
  GistCui.delete("5464465") # => 404
end
