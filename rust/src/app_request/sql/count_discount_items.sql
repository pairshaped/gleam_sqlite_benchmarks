-- returns: ValueRow
select count(*) as value from app_discount_items where item_id = @event_id and item_type = @item_type
