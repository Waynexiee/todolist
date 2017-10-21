create table lists(
  id serial primary key,
  name text not null unique
);

create table todos(
  id serial primary key,
  name text not null,
  completed boolean not null default false,
  list_id integer not null references lists(id)
);
