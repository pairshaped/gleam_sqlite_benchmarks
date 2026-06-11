-- returns: ValueRow
select count(*) as value from app_addons where addonable_id = @event_id and addonable_type = @addonable_type
