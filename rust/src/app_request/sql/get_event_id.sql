-- returns: ValueRow
select id as value from app_events where club_id = @club_id and id = @event_id
