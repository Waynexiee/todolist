require 'sinatra'
require "sinatra/reloader" if development?
require 'tilt/erubis'
require 'sinatra/content_for'

enable :sessions

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

    incomplete_lists.each { |list| yield(list,lists.index(list)) }
    completed_lists.each { |list| yield(list,lists.index(list)) }
  end

  def sort_todos(todos, &block)
    completed_todos, incomplete_todos = todos[:todos].partition {|todo| todo[:completed]}

    incomplete_todos.each { |todo| yield(todo,todos[:todos].index(todo)) }
    completed_todos.each { |todo| yield(todo,todos[:todos].index(todo)) }
  end

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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'You create the lists successfully!'
    redirect '/lists'
  end
end

get '/lists/:id' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]

  erb :list, layout: :layout
end

get '/lists/:id/edit' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

post '/lists/:id' do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
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
  session[:lists].delete_at(id)
  session[:success] = "You delete the list successfully!"
  redirect '/lists'
end

post '/lists/:id/todos' do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @text = params[:todo]
  text = params[:todo].strip
  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo is added."
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:id/delete' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:id].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = "Delete the todo successfully."
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/todos/:id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:id].to_i
  is_completed = (params[:completed] == "true")
  @list[:todos][todo_id][:completed] = is_completed
  session[:success] = "To do updated successfully."
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/completed' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "To do updated successfully."
  redirect "/lists/#{@list_id}"
end
