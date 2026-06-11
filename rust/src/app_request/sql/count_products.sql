-- returns: ValueRow
select count(*) as value from app_products where club_id = @club_id and active = @active and product_type in (@product_type_1, @product_type_2)
