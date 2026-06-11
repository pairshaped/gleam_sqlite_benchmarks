-- returns: ValueRow
with recursive parents(id, parent_id) as (
    select id, parent_id from app_clubs where id = @club_id
    union all
    select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
)
select cast(coalesce(sum(id), 0) as integer) as value from parents
