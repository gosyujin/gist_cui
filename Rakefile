require "bundler/gem_tasks"

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
require 'gist_cui'

task :default => :gists

# rake gists user=user_login
desc "get gists "
task :gists do
  user = ENV["user"]
  if user.nil? then
    GistCui.gists()
  else
    GistCui.gists(user)
  end
end

# rake gist id=id
desc "get gist"
task :gist do
  id = ENV["id"]
  abort("rake aborted: id cannot be blank") if id.nil?

  GistCui.gist(id)
end

# rake create file=file_path desc=description
desc "create gist"
task :create do
  file = ENV["file"]
  abort("rake aborted: file cannot be blank") if file.nil?
  desc = ENV["desc"]

  GistCui.create(file, desc)
end

# rake edit id=id file=file_path desc=description
desc "edit gist"
task :edit do
  id = ENV["id"]
  abort("rake aborted: id cannot be blank") if id.nil?
  file = ENV["file"]
  abort("rake aborted: file cannot be blank") if file.nil?
  desc = ENV["desc"]

  GistCui.edit(id, file, desc)
end

# rake delete id=id
desc "delete gist"
task :delete do
  id = ENV["id"]
  abort("rake aborted: id cannot be blank") if id.nil?

  GistCui.delete(id)
end

# get access token
desc "get access token"
task :token do
  GistCui.access_token
end
