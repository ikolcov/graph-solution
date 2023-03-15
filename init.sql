begin;

create table employee
(
    id integer primary key,
    head integer,
    name text not null
);

create or replace function add_employee(employee_id int, employee_head int, employee_name text)
returns void
language sql
as
$$
insert
into employee(id, head, name)
values(employee_id, employee_head, employee_name);
$$;

create or replace function update_employee_head(employee_id int, new_head int)
returns void
language sql
as
$$
update employee
set head = new_head
where id = employee_id;
$$;

create or replace function get_department(head_id int)
returns table(
    employee_id integer,
    employee_head integer,
    employee_name text
)
language sql
as
$$
select id, head, name
from employee
where id = head_id or head = head_id;
$$;

create or replace function get_leaves()
returns table(
    employee_id integer,
    employee_head integer,
    employee_name text
)
language sql
as
$$

with
heads as (
    select distinct head from employee
    where head is not null
),
employees_joined_with_heads as (
    select employee.id, employee.head, employee.name, heads.head as joined_head from employee
    left join heads
    on employee.id = heads.head
)

select id, head, name
from employees_joined_with_heads
where joined_head is null;
$$;

create or replace function get_hierarchy_list(start_id int)
returns table(
    employee_id integer,
    employee_head integer,
    employee_name text
)
language sql
as
$$
with recursive heads as (
	select * from employee
	where id = start_id
	union all
    select employee.* from employee
    inner join heads on employee.id = heads.head
)
select * from heads;
$$;

create or replace function get_department_count(head_id int)
returns table(
    count integer
)
language sql
as
$$
with recursive members as (
	select * from employee
	where id = head_id
	union
    select employee.* from employee
    inner join members on employee.head = members.id
)
select count(1) from members;
$$;

create or replace function check_one_root()
returns table(
    has_one_root boolean
)
language sql
as
$$
select count(1) = 1 from employee where head is null
$$;

create or replace function check_no_cycles()
returns table(
    no_cycles boolean
)
language sql
as
$$
with recursive search_graph(id, head, name, depth) as (
    select g.id, g.head, g.name, 1
    from employee g
  union all
    select g.id, g.head, g.name, sg.depth + 1
    from employee g, search_graph sg
    where g.id = sg.head
) cycle id set is_cycle using path
select count(1) = 0 from search_graph where is_cycle
$$;

create or replace function get_rank(employee_id int)
returns table(
    rank integer
)
language sql
as
$$
with recursive heads as (
	select * from employee
	where id = employee_id
	union all
    select employee.* from employee
    inner join heads on employee.id = heads.head
)
select count(1) from heads;
$$;

create or replace function print_hierarchy(start_id int)
returns table(
    name text
)
language sql
as
$$
with recursive heads as (
	select * from employee
	where id = start_id
	union all
    select employee.* from employee
    inner join heads on employee.id = heads.head
),
heads_list as (
    select name
    from heads
    order by row_number() over() desc
)
select concat(
    repeat(
        '  ',
        cast(row_number() over() as integer)
    ),
    name
) from heads_list;
$$;

create or replace function get_path(a int, b int)
returns table(
    employee_id integer,
    employee_head integer,
    employee_name text
)
language sql
as
$$
with recursive a_heads as (
	select * from employee
	where id = a
	union all
    select employee.* from employee
    inner join a_heads on employee.id = a_heads.head
),
b_heads as (
	select * from employee
	where id = b
	union all
    select employee.* from employee
    inner join b_heads on employee.id = b_heads.head
),
joined as (
    select *
    from a_heads inner join b_heads
    on a_heads.id = b_heads.id
),
a_heads_with_lca as (
    select * from a_heads limit ((select count(1) from a_heads) - (select count(1) from joined) + 1)
),
b_heads_without_lca as (
    select * from b_heads limit ((select count(1) from b_heads) - (select count(1) from joined))
)
select * from a_heads_with_lca
union all
(select * from b_heads_without_lca order by row_number() over() desc)
$$;

commit;
