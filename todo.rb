require 'sinatra'
require "sinatra/reloader" if development?
require 'tilt/erubis'
require 'sinatra/content_for'
require "rack"
require 'securerandom'

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
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
    list = session[:lists].find{|list| list[:id] == id}
    return list if list

    session[:error] = "The specified list was not found."
    redirect "/lists"
  end

end

def next_element_id(elements)
  max = elements.map {|element| element[:id]}.max || 0
  max + 1
end



get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]
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
    id = next_element_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
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
    @list[:name] = list_name
    session[:success] = 'You edit the list successfully!'
    redirect '/lists'
  end
end


post '/lists/:id/delete' do
  id = params[:id].to_i
  session[:lists].reject! {|list| list[:id] == id}
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
  @text = params[:todo]
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_element_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}
    session[:success] = "The todo is added."
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:id/delete' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  @list[:todos].reject! {|todo| todo[:id] == todo_id }
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
  todo = @list[:todos].find {|todo| todo[:id] == todo_id}
  todo[:completed] = is_completed
  session[:success] = "To do updated successfully."
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/completed' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "To do updated successfully."
  redirect "/lists/#{@list_id}"
end
