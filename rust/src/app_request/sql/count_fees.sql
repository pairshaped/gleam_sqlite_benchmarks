-- returns: ValueRow
select count(*) as value from app_fees where club_id in (@club_id, @parent_id, @grandparent_id) and active = @active
