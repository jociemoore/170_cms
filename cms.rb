require "redcarpet"
require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "yaml"
require "bcrypt"


configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  if ENV["RACK_ENV"] == "test"
    @files = Dir.entries("test/data")
  else
    @files = Dir.entries("data")
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def user_data
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def require_user_account
  if !session[:username]
    session[:message] = "You must be logged in to do that." 
    redirect "/"
  end
end

get "/" do
  erb :index
end

get "/login" do 
  erb :login
end

post "/login" do
  erb :login
end

post "/signup" do
  erb :signup
end

post "/create-user" do
  user = params[:username]

  credentials = YAML.load_file(user_data)
  credentials[user] = BCrypt::Password.create(params[:password])
  File.write(user_data, YAML.dump(credentials))

  session[:username] = params[:username]
  session[:message] = "Welcome! Your account has been created."
  redirect "/"
end

post "/" do
  new_content = params[:file_contents]
  document = session.delete(:document)
  path = File.join(data_path, document)

  File.open(path, 'w') do |file|
    file.write(new_content)
  end
  session[:message] = "#{document} has been updated."

  redirect "/"
end

post "/verify" do
  user = params[:username]
  user_credentials = YAML.load_file(user_data)
  session[:username] = params[:username]

  if user_credentials.key?(user) && BCrypt::Password.new(user_credentials[user]) == params[:password]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid Credentials"
    redirect "/login"
  end
end

post "/logout" do
  session.delete(:username)
  session[:message] = "You've been logged out."
  redirect "/"
end

get "/new" do
  require_user_account
  erb :new
end

post "/new/create" do
  require_user_account

  new_document = params[:new_document]

  if !new_document.include?('.') && new_document.size > 0 
    session[:error] = "Please enter a filename with an extension (i.e. 'new_file.txt')."
    redirect "/new"
  elsif new_document.size > 0 
    File.new(File.join(data_path, new_document), "w").path
    session[:message] = "#{new_document} was created."

    redirect "/"
  else
    session[:error] = "Please enter a filename."
    redirect "/new"
  end
end 

get "/:file" do
  document = File.basename(params[:file])
  path = File.join(data_path, document)

  if !@files.include?(document)
    session[:error] = "#{document} does not exist." 
    redirect "/"
  elsif document.include?(".md")
    contents = File.read(path)
    erb render_markdown(contents)
  elsif document.include?(".txt")
    headers["Content-Type"] = "text/plain"
    File.read(path)
  end
end

get "/:file/edit" do 
  require_user_account

  session[:document] = params[:file]
  @document = session[:document]
  path = File.join(data_path, @document)
  @contents = File.read(path)

  erb :edit
end

post "/:file/delete" do 
  require_user_account

  document = params[:file]
  path = File.join(data_path, document)
  File.delete(path)

  session[:message] = "#{document} was deleted."
  redirect "/"
end

