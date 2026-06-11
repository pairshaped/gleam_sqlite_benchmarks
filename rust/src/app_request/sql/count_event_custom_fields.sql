-- returns: ValueRow
select count(*) as value from app_event_custom_fields where event_id = @event_id
