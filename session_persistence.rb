require "pg"
class SessionPersistence
  def initialize

    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
  end

  def query(statement, *params)

    @db.exec_params(statement, params)
  end

  def find_list(id)
    sql = "select * from lists where id = $1"
    result = query(sql, id)
    tuple = result.first
    list_id = tuple["id"].to_i
    todos = find_todos_for_list(list_id)
    {id: tuple["id"], name: tuple["name"], todos: todos}
  end

  def all_list
    sql = "select * from lists"
    result = query(sql)
    result.map do |todo_tuple|
      list_id = todo_tuple["id"]
      todos = find_todos_for_list(list_id)

      {id: todo_tuple["id"].to_i, name: todo_tuple["name"], todos: todos}

    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(id)
    query("DELETE FROM lists WHERE id = $1", id)
    query("DELETE FROM todos WHERE list_id = $1", id)
  end

  def update_list_name(id, new_name)
    sql = "update lists set name=$1 where id=$2"
    query(sql, new_name, id)
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (list_id, name) VALUES ($1, $2)"
    query(sql, list_id, todo_name)
  end

  def delete_todo_from_list(list_id, todo_id)
    sql = "delete from todos where list_id = $1 and id = $2"
    query(sql, list_id, todo_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE id = $2 AND list_id = $3"
    query(sql, new_status, todo_id, list_id)
  end

  def mark_all_todos_as_completed(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  def disconnect
    @db.close
  end

  private

  def find_todos_for_list(list_id)
    todos_sql = "select * from todos where list_id=$1"
    result_todos = query(todos_sql, list_id)
    result_todos.map do |todo_tuple|
      {id: todo_tuple["id"].to_i, name: todo_tuple["name"],completed: todo_tuple["completed"] == "t"}
    end
  end

end
