require 'sinatra'

require 'tilt/erubis'
require 'sinatra/content_for'
require "rack"
require 'securerandom'
require_relative 'session_persistence'

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  set :erb, :escape_html => true

end

configure(:development) do
  require "sinatra/reloader"
  also_reload "session_persistence.rb"
end

helpers do
  def validate_list(list_name)
    if !(1..100).cover? list_name.size
      'List name must be between 1 and 100 charactors.'
    elsif session[:lists].any? { |list| list[:name] == list_name }
      'List name must be unique.'
    end
  end

  def error_for_todo(name)
    if !(1..100).cover? name.size
      "Todo must be between 1 and 100 characters."
    end
  end

  def list_complete?(list)
    list[:todos].size > 0 && todos_remaining_todo(list) == 0
  end

  def list_class(list)
    return "complete" if list_complete?(list)
  end

  def todo_count(list)
    list[:todos].size
  end

  def todos_remaining_todo(list)
    list[:todos].count {|todo| !todo[:completed]}
  end

  def sort_lists(lists, &block)
    completed_lists, incomplete_lists = lists.partition {|list| list_complete?(list)}

    incomplete_lists.each { |list| yield(list) }
    completed_lists.each { |list| yield(list) }
  end

  def sort_todos(todos, &block)
    completed_todos, incomplete_todos = todos[:todos].partition {|todo| todo[:completed]}

    incomplete_todos.each { |todo| yield(todo) }
    completed_todos.each { |todo| yield(todo) }
  end

  def load_list(id)
    list = @storage.find_list(id)
    return list if list

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end

end




before do
  @storage = SessionPersistence.new
end

after do
  @storage.disconnect
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = @storage.all_list
  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

post '/lists' do
  list_name = params[:list_name].strip
  error = validate_list(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    @storage.create_new_list(list_name)
    session[:success] = 'You create the lists successfully!'
    redirect '/lists'
  end
end

get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

post '/lists/:id' do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  error = validate_list(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = 'You edit the list successfully!'
    redirect '/lists'
  end
end


post '/lists/:id/delete' do
  id = params[:id].to_i
  @storage.delete_list(id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

post '/lists/:id/todos' do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, text)
    session[:success] = "The todo is added."
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @storage.delete_todo_from_list(@list_id, todo_id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_id = params[:id].to_i
  is_completed = (params[:completed] == "true")
  @storage.update_todo_status(@list_id,todo_id,is_completed)
  session[:success] = "To do updated successfully."
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/completed' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @storage.mark_all_todos_as_completed(@list_id)
  session[:success] = "To do updated successfully."
  redirect "/lists/#{@list_id}"
end
