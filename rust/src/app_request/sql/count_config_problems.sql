-- returns: ValueRow
select count(*) as value from app_config_problems where club_id = @club_id and ignored = @ignored
