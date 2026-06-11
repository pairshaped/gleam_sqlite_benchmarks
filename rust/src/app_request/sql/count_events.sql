-- returns: ValueRow
select count(*) as value from app_events where club_id = @club_id
