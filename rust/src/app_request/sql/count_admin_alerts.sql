-- returns: ValueRow
select count(*) as value from app_admin_alerts where (country = @country or country is null) and (club_type = @club_type or club_type is null)
