import gleam/dynamic/decode
import sqlight

/// Shared return type for queries in this directory:
///   ../rust/src/app_request/sql/count_addons.sql
///   ../rust/src/app_request/sql/count_admin_alerts.sql
///   ../rust/src/app_request/sql/count_config_problems.sql
///   ../rust/src/app_request/sql/count_custom_fields.sql
///   ../rust/src/app_request/sql/count_discount_items.sql
///   ../rust/src/app_request/sql/count_discounts.sql
///   ../rust/src/app_request/sql/count_event_custom_fields.sql
///   ../rust/src/app_request/sql/count_events.sql
///   ../rust/src/app_request/sql/count_fees.sql
///   ../rust/src/app_request/sql/count_products.sql
///   ../rust/src/app_request/sql/count_sponsors.sql
///   ../rust/src/app_request/sql/count_tags.sql
///   ../rust/src/app_request/sql/count_taxes.sql
///   ../rust/src/app_request/sql/get_branding_palette_id.sql
///   ../rust/src/app_request/sql/get_club_id.sql
///   ../rust/src/app_request/sql/get_club_id_by_subdomain.sql
///   ../rust/src/app_request/sql/get_event_counter.sql
///   ../rust/src/app_request/sql/get_event_id.sql
///   ../rust/src/app_request/sql/get_fee_id.sql
///   ../rust/src/app_request/sql/get_product_id.sql
///   ../rust/src/app_request/sql/get_user_id.sql
///   ../rust/src/app_request/sql/sum_parent_chain.sql
pub type ValueRow {
  ValueRow(value: Int)
}

fn value_row_decoder() -> decode.Decoder(ValueRow) {
  use value <- decode.field(0, decode.int)
  decode.success(ValueRow(value:))
}

/// Generated from ../rust/src/app_request/sql/count_addons.sql
pub fn count_addons(
  db db: sqlight.Connection,
  event_id event_id: Int,
  addonable_type addonable_type: String,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_addons where addonable_id = @event_id and addonable_type = @addonable_type",
    on: db,
    with: [sqlight.int(event_id), sqlight.text(addonable_type)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_admin_alerts.sql
pub fn count_admin_alerts(
  db db: sqlight.Connection,
  country country: String,
  club_type club_type: String,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_admin_alerts where (country = @country or country is null) and (club_type = @club_type or club_type is null)",
    on: db,
    with: [sqlight.text(country), sqlight.text(club_type)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_config_problems.sql
pub fn count_config_problems(
  db db: sqlight.Connection,
  club_id club_id: Int,
  ignored ignored: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_config_problems where club_id = @club_id and ignored = @ignored",
    on: db,
    with: [sqlight.int(club_id), sqlight.int(ignored)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_custom_fields.sql
pub fn count_custom_fields(
  db db: sqlight.Connection,
  club_id club_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_custom_fields where club_id = @club_id",
    on: db,
    with: [sqlight.int(club_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_discount_items.sql
pub fn count_discount_items(
  db db: sqlight.Connection,
  event_id event_id: Int,
  item_type item_type: String,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_discount_items where item_id = @event_id and item_type = @item_type",
    on: db,
    with: [sqlight.int(event_id), sqlight.text(item_type)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_discounts.sql
pub fn count_discounts(
  db db: sqlight.Connection,
  club_id club_id: Int,
  active active: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_discounts where club_id = @club_id and active = @active",
    on: db,
    with: [sqlight.int(club_id), sqlight.int(active)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_event_custom_fields.sql
pub fn count_event_custom_fields(
  db db: sqlight.Connection,
  event_id event_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_event_custom_fields where event_id = @event_id",
    on: db,
    with: [sqlight.int(event_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_events.sql
pub fn count_events(
  db db: sqlight.Connection,
  club_id club_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_events where club_id = @club_id",
    on: db,
    with: [sqlight.int(club_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_fees.sql
pub fn count_fees(
  db db: sqlight.Connection,
  club_id club_id: Int,
  parent_id parent_id: Int,
  grandparent_id grandparent_id: String,
  active active: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_fees where club_id in (@club_id, @parent_id, @grandparent_id) and active = @active",
    on: db,
    with: [
      sqlight.int(club_id),
      sqlight.int(parent_id),
      sqlight.text(grandparent_id),
      sqlight.int(active),
    ],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_products.sql
pub fn count_products(
  db db: sqlight.Connection,
  club_id club_id: Int,
  active active: Int,
  product_type_1 product_type_1: String,
  product_type_2 product_type_2: String,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_products where club_id = @club_id and active = @active and product_type in (@product_type_1, @product_type_2)",
    on: db,
    with: [
      sqlight.int(club_id),
      sqlight.int(active),
      sqlight.text(product_type_1),
      sqlight.text(product_type_2),
    ],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_sponsors.sql
pub fn count_sponsors(
  db db: sqlight.Connection,
  club_id club_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_sponsors where club_id = @club_id",
    on: db,
    with: [sqlight.int(club_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_tags.sql
pub fn count_tags(
  db db: sqlight.Connection,
  club_id club_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_tags where club_id = @club_id",
    on: db,
    with: [sqlight.int(club_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/count_taxes.sql
pub fn count_taxes(
  db db: sqlight.Connection,
  province province: String,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select count(*) as value from app_taxes where province = @province",
    on: db,
    with: [sqlight.text(province)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_branding_palette_id.sql
pub fn get_branding_palette_id(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_branding_palettes where id = @id",
    on: db,
    with: [sqlight.int(id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_club_id.sql
pub fn get_club_id(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_clubs where id = @id",
    on: db,
    with: [sqlight.int(id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_club_id_by_subdomain.sql
pub fn get_club_id_by_subdomain(
  db db: sqlight.Connection,
  subdomain subdomain: String,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_clubs where subdomain = @subdomain",
    on: db,
    with: [sqlight.text(subdomain)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_event_counter.sql
pub fn get_event_counter(
  db db: sqlight.Connection,
  event_id event_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select counter as value from app_events where id = @event_id",
    on: db,
    with: [sqlight.int(event_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_event_id.sql
pub fn get_event_id(
  db db: sqlight.Connection,
  club_id club_id: Int,
  event_id event_id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_events where club_id = @club_id and id = @event_id",
    on: db,
    with: [sqlight.int(club_id), sqlight.int(event_id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_fee_id.sql
pub fn get_fee_id(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_fees where id = @id",
    on: db,
    with: [sqlight.int(id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_product_id.sql
pub fn get_product_id(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_products where id = @id",
    on: db,
    with: [sqlight.int(id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/get_user_id.sql
pub fn get_user_id(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "select id as value from app_users where id = @id",
    on: db,
    with: [sqlight.int(id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/sum_parent_chain.sql
pub fn sum_parent_chain(
  db db: sqlight.Connection,
  id id: Int,
) -> Result(List(ValueRow), sqlight.Error) {
  sqlight.query(
    "with recursive parents(id, parent_id) as ( select id, parent_id from app_clubs where id = @club_id union all select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id ) select cast(coalesce(sum(id), 0) as integer) as value from parents",
    on: db,
    with: [sqlight.int(id)],
    expecting: value_row_decoder(),
  )
}

/// Generated from ../rust/src/app_request/sql/update_event.sql
pub fn update_event(
  db db: sqlight.Connection,
  name name: String,
  event_id event_id: Int,
) -> Result(List(Nil), sqlight.Error) {
  sqlight.query(
    "update app_events set counter = counter + 1, name = @name where id = @event_id",
    on: db,
    with: [sqlight.text(name), sqlight.int(event_id)],
    expecting: decode.success(Nil),
  )
}
