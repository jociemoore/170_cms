ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def developer_session
    {"rack.session" => {username: "developer"}}
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "changes.txt"
    assert_includes last_response.body, "about.md"
  end

  def test_known_file
    content = '2015 - Ruby 2.3 released'
    create_document "history.txt", content

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "2015 - Ruby 2.3 released"
  end

  def test_markdown_file
    content = "<h1><em>Yukihiro Matsumoto</em></h1"
    create_document "about.md", content

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<em>Yukihiro Matsumoto</em>"
  end

  def test_unknown_file
    get "/whatever.txt"
    
    assert_equal 302, last_response.status
    assert_equal "whatever.txt does not exist.", session[:error]
  end

  # WITH Login Credentials

  def test_edit_file
    content = "Editing contents of history.txt:"
    create_document "history.txt", content

    get "/history.txt/edit", {}, developer_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Editing contents of history.txt:"

    post "/", params={:file_contents => File.read(File.join(data_path, "history.txt"))}
    assert_equal 302, last_response.status
    assert_equal "history.txt has been updated.", session[:message]
  end

  def test_new_file_with_filename
    get "/new", {}, developer_session
    assert_includes last_response.body, "Add a new document:"

    post "/new/create", params={:new_document => "contacts.txt"}
    assert_equal 302, last_response.status
    assert_equal "contacts.txt was created.", session[:message]
    assert_includes Dir.entries("test/data"), "contacts.txt"
  end

  def test_new_file_no_filename
    post "/new/create", params={:new_document => ""}, developer_session
    assert_equal 302, last_response.status
    assert_equal "Please enter a filename.", session[:error]
  end

  def test_delete_file
    create_document "contacts.txt"
    create_document "chapters.txt"

    post "contacts.txt/delete", {}, developer_session
    assert_equal 302, last_response.status
    assert_equal "contacts.txt was deleted.", session[:message]

    get last_response["Location"]
    assert_includes last_response.body, "chapters.txt</a>"
    refute_includes last_response.body, "contacts.txt</a>"
  end

  # WITHOUT Login Credentials

  def test_edit_file_without_login
    content = "Editing contents of history.txt:"
    create_document "history.txt", content

    get "/history.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be logged in to do that.", session[:message]
  end

  def test_new_file_with_filename_without_login
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be logged in to do that.", session[:message]
  end

  def test_new_file_no_filename_without_login
    post "/new/create", params={:new_document => ""}

    assert_equal 302, last_response.status
    assert_equal "You must be logged in to do that.", session[:message]
  end

  def test_delete_file_without_login
    create_document "contacts.txt"
    create_document "chapters.txt"

    post "contacts.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be logged in to do that.", session[:message]
  end

  def test_sign_in_success
    post "/login"
    assert_includes last_response.body, "<input name=\"username\""

    post "/verify", params={:username => "developer", :password => "letmein"}
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "developer", session[:username]
  end

  def test_sign_in_fail
    post "/verify", params={:username => "Susie", :password => "Q"}
    assert_equal 302, last_response.status
    assert_equal "Invalid Credentials", session[:error]
    assert_equal "Susie", session[:username]
  end

  def test_sign_out
    post "/logout", params={:username => "developer"}
    assert_equal 302, last_response.status
    assert_nil session[:username]
    assert_equal "You've been logged out.", session[:message]
  end

  def test_new_user
    post "/signup"
    assert_includes last_response.body, "Sign Up</button>"

    post "/create-user", params={:username => "FreeWilly", :password => "fish"}
    assert_equal 302, last_response.status
    assert_equal "Welcome! Your account has been created.", session[:message]

    post "/logout"
    assert_nil session[:username]

    post "/verify", params={:username => "FreeWilly", :password => "fish"}
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "FreeWilly", session[:username]
  end
end

