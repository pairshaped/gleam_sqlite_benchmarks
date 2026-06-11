-- returns: ValueRow
select count(*) as value from app_discounts where club_id = @club_id and active = @active
