use rusqlite::Connection;
use sqlx::sqlite::{SqliteConnectOptions, SqliteJournalMode, SqlitePool, SqlitePoolOptions};
use sqlx::Connection as SqlxConnection;
use sqlx::SqliteConnection;
use std::error::Error;
use std::fs;
use std::io;
use std::str::FromStr;
use std::time::{Duration, Instant};

type BenchResult<T> = Result<T, Box<dyn Error + Send + Sync>>;

const DEFAULT_ROW_COUNT: i64 = 10_000;
const DB_PATH: &str = "rust_benchmark.sqlite3";

#[tokio::main]
async fn main() -> BenchResult<()> {
    let rows = row_count_from_args();
    remove_sqlite_files(DB_PATH)?;

    println!("case,items,micros,us_per_item,check");

    measure_sync("rust_rusqlite/app_request/seed_dummy_data", 1, || {
        seed_app_request_data_rusqlite()
    })?;
    measure_sync("rust_rusqlite/app_request/admin_item_edit", rows, || {
        admin_item_edit_requests_rusqlite(rows)
    })?;
    measure_sync("rust_rusqlite/app_request/admin_item_update", rows, || {
        admin_item_update_requests_rusqlite(rows)
    })?;

    remove_sqlite_files(DB_PATH)?;
    let pool = open_pool(5).await?;
    measure("rust_sqlx/app_request/seed_dummy_data", 1, || {
        seed_app_request_data(&pool)
    })
    .await?;
    measure("rust_sqlx/app_request/admin_item_edit", rows, || {
        admin_item_edit_requests(&pool, rows)
    })
    .await?;
    measure("rust_sqlx/app_request/admin_item_update", rows, || {
        admin_item_update_requests(&pool, rows)
    })
    .await?;

    pool.close().await;

    remove_sqlite_files(DB_PATH)?;
    let pool = open_pool(1).await?;
    measure("rust_sqlx_pool1/app_request/seed_dummy_data", 1, || {
        seed_app_request_data(&pool)
    })
    .await?;
    measure("rust_sqlx_pool1/app_request/admin_item_edit", rows, || {
        admin_item_edit_requests(&pool, rows)
    })
    .await?;
    measure(
        "rust_sqlx_pool1/app_request/admin_item_update",
        rows,
        || admin_item_update_requests(&pool, rows),
    )
    .await?;

    pool.close().await;

    remove_sqlite_files(DB_PATH)?;
    let pool = open_pool(1).await?;
    measure("rust_sqlx_conn/app_request/seed_dummy_data", 1, || {
        seed_app_request_data(&pool)
    })
    .await?;
    let mut conn = pool.acquire().await?;
    measure("rust_sqlx_conn/app_request/admin_item_edit", rows, || {
        admin_item_edit_requests_conn(&mut conn, rows)
    })
    .await?;
    measure("rust_sqlx_conn/app_request/admin_item_update", rows, || {
        admin_item_update_requests_conn(&mut conn, rows)
    })
    .await?;
    drop(conn);
    pool.close().await;

    remove_sqlite_files(DB_PATH)?;
    let mut conn = open_sqlx_connection().await?;
    measure("rust_sqlx_direct/app_request/seed_dummy_data", 1, || {
        seed_app_request_data_conn(&mut conn)
    })
    .await?;
    measure("rust_sqlx_direct/app_request/admin_item_edit", rows, || {
        admin_item_edit_requests_conn(&mut conn, rows)
    })
    .await?;
    measure(
        "rust_sqlx_direct/app_request/admin_item_update",
        rows,
        || admin_item_update_requests_conn(&mut conn, rows),
    )
    .await?;
    conn.close().await?;

    remove_sqlite_files(DB_PATH)?;
    let mut conn = open_sqlx_tuned_connection().await?;
    measure(
        "rust_sqlx_direct_tuned/app_request/seed_dummy_data",
        1,
        || seed_app_request_data_conn(&mut conn),
    )
    .await?;
    measure(
        "rust_sqlx_direct_tuned/app_request/admin_item_edit",
        rows,
        || admin_item_edit_requests_conn(&mut conn, rows),
    )
    .await?;
    measure(
        "rust_sqlx_direct_tuned/app_request/admin_item_update",
        rows,
        || admin_item_update_requests_conn(&mut conn, rows),
    )
    .await?;
    conn.close().await?;

    remove_sqlite_files(DB_PATH)?;
    let mut conn = open_sqlx_connection().await?;
    measure("rust_sqlx_manual_tx/app_request/seed_dummy_data", 1, || {
        seed_app_request_data_conn(&mut conn)
    })
    .await?;
    measure(
        "rust_sqlx_manual_tx/app_request/admin_item_update",
        rows,
        || admin_item_update_requests_conn_manual_tx(&mut conn, rows),
    )
    .await?;
    conn.close().await?;

    Ok(())
}

fn measure_sync<F>(name: &str, items: i64, work: F) -> BenchResult<()>
where
    F: FnOnce() -> BenchResult<i64>,
{
    let start = Instant::now();
    let check = work()?;
    let elapsed = start.elapsed().as_micros() as i64;
    let us_per_item = elapsed / items;
    println!("{name},{items},{elapsed},{us_per_item},{check}");
    Ok(())
}

fn row_count_from_args() -> i64 {
    std::env::args()
        .nth(1)
        .and_then(|arg| arg.parse::<i64>().ok())
        .filter(|rows| *rows > 0)
        .unwrap_or(DEFAULT_ROW_COUNT)
}

async fn measure<F, Fut>(name: &str, items: i64, work: F) -> BenchResult<()>
where
    F: FnOnce() -> Fut,
    Fut: std::future::Future<Output = BenchResult<i64>>,
{
    let start = Instant::now();
    let check = work().await?;
    let elapsed = start.elapsed().as_micros() as i64;
    let us_per_item = elapsed / items;
    println!("{name},{items},{elapsed},{us_per_item},{check}");
    Ok(())
}

fn remove_sqlite_files(path: &str) -> io::Result<()> {
    for suffix in ["", "-wal", "-shm"] {
        let file_path = format!("{path}{suffix}");
        match fs::remove_file(&file_path) {
            Ok(()) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(error),
        }
    }
    Ok(())
}

async fn open_pool(max_connections: u32) -> Result<SqlitePool, sqlx::Error> {
    SqlitePoolOptions::new()
        .max_connections(max_connections)
        .connect_with(sqlx_connect_options()?)
        .await
}

async fn open_sqlx_connection() -> Result<SqliteConnection, sqlx::Error> {
    SqliteConnection::connect_with(&sqlx_connect_options()?).await
}

async fn open_sqlx_tuned_connection() -> Result<SqliteConnection, sqlx::Error> {
    SqliteConnection::connect_with(
        &sqlx_connect_options()?
            .serialized(false)
            .command_buffer_size(1)
            .row_buffer_size(1)
            .statement_cache_capacity(1000),
    )
    .await
}

fn sqlx_connect_options() -> Result<SqliteConnectOptions, sqlx::Error> {
    let options = SqliteConnectOptions::from_str(&format!("sqlite://{DB_PATH}"))?
        .create_if_missing(true)
        .journal_mode(SqliteJournalMode::Wal)
        .busy_timeout(Duration::from_millis(5000))
        .foreign_keys(true);

    Ok(options)
}

async fn execute_batch(pool: &SqlitePool, sql: &str) -> Result<(), sqlx::Error> {
    for statement in sql
        .split(';')
        .map(str::trim)
        .filter(|part| !part.is_empty())
    {
        let statement = statement.to_string();
        sqlx::query(sqlx::AssertSqlSafe(statement))
            .execute(pool)
            .await?;
    }
    Ok(())
}

async fn execute_batch_conn(conn: &mut SqliteConnection, sql: &str) -> Result<(), sqlx::Error> {
    for statement in sql
        .split(';')
        .map(str::trim)
        .filter(|part| !part.is_empty())
    {
        let statement = statement.to_string();
        sqlx::query(sqlx::AssertSqlSafe(statement))
            .execute(&mut *conn)
            .await?;
    }
    Ok(())
}

async fn seed_app_request_data(pool: &SqlitePool) -> BenchResult<i64> {
    execute_batch(pool, app_request_seed_sql()).await?;

    Ok(100)
}

async fn seed_app_request_data_conn(conn: &mut SqliteConnection) -> BenchResult<i64> {
    execute_batch_conn(conn, app_request_seed_sql()).await?;

    Ok(100)
}

fn app_request_seed_sql() -> &'static str {
    "
    pragma journal_mode = WAL;
    pragma busy_timeout = 5000;
    pragma foreign_keys = ON;

    drop table if exists app_users;
    drop table if exists app_clubs;
    drop table if exists app_events;
    drop table if exists app_sponsors;
    drop table if exists app_tags;
    drop table if exists app_taxes;
    drop table if exists app_fees;
    drop table if exists app_products;
    drop table if exists app_addons;
    drop table if exists app_custom_fields;
    drop table if exists app_event_custom_fields;
    drop table if exists app_discounts;
    drop table if exists app_discount_items;
    drop table if exists app_branding_palettes;
    drop table if exists app_admin_alerts;
    drop table if exists app_config_problems;

    create table app_users (id integer primary key, name text not null);
    create table app_clubs (id integer primary key, parent_id integer, subdomain text not null, province text not null);
    create index app_clubs_subdomain on app_clubs(subdomain);
    create index app_clubs_parent_id on app_clubs(parent_id);
    create table app_events (id integer primary key, club_id integer not null, name text not null, counter integer not null);
    create index app_events_club_id on app_events(club_id);
    create table app_sponsors (id integer primary key, club_id integer not null, name text not null);
    create index app_sponsors_club_id on app_sponsors(club_id);
    create table app_tags (id integer primary key, club_id integer not null, name text not null);
    create index app_tags_club_id on app_tags(club_id);
    create table app_taxes (id integer primary key, province text not null, name text not null);
    create index app_taxes_province on app_taxes(province);
    create table app_fees (id integer primary key, club_id integer not null, name text not null, active integer not null);
    create index app_fees_club_id on app_fees(club_id, active);
    create table app_products (id integer primary key, club_id integer not null, active integer not null, product_type text not null, name text not null);
    create index app_products_club_type on app_products(club_id, active, product_type);
    create table app_addons (id integer primary key, addonable_id integer not null, addonable_type text not null, addable_kind text not null, addable_id integer not null, position integer not null);
    create index app_addons_addonable on app_addons(addonable_id, addonable_type);
    create table app_custom_fields (id integer primary key, club_id integer not null, position integer not null);
    create index app_custom_fields_club_id on app_custom_fields(club_id);
    create table app_event_custom_fields (id integer primary key, event_id integer not null, position integer not null);
    create index app_event_custom_fields_event_id on app_event_custom_fields(event_id);
    create table app_discounts (id integer primary key, club_id integer not null, active integer not null);
    create index app_discounts_club_id on app_discounts(club_id, active);
    create table app_discount_items (id integer primary key, item_id integer not null, item_type text not null, discount_id integer not null);
    create index app_discount_items_item on app_discount_items(item_id, item_type);
    create table app_branding_palettes (id integer primary key, slug text not null);
    create table app_admin_alerts (id integer primary key, country text, club_type text);
    create table app_config_problems (id integer primary key, club_id integer not null, ignored integer not null);
    create index app_config_problems_club_id on app_config_problems(club_id, ignored);

    insert into app_users (id, name) values (1, 'Admin');
    insert into app_clubs (id, parent_id, subdomain, province) values
        (403, null, 'canada', 'ON'),
        (411, 403, 'ontario', 'ON'),
        (418, 411, 'demo', 'ON');
    insert into app_branding_palettes (id, slug) values (1, 'default');
    insert into app_admin_alerts (id, country, club_type) values (330, 'Canada', 'club');
    insert into app_config_problems (id, club_id, ignored) values (1, 418, 0);
    insert into app_taxes (id, province, name) values (1, 'ON', 'HST'), (2, 'ON', 'GST');

    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 100)
    insert into app_events (id, club_id, name, counter)
    select id, 418, 'Event ' || id, 0 from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 20)
    insert into app_sponsors (id, club_id, name) select id, 418, 'Sponsor ' || id from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 30)
    insert into app_tags (id, club_id, name) select id, 418, 'Tag ' || id from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 12)
    insert into app_fees (id, club_id, name, active)
    select id, case id % 3 when 0 then 403 when 1 then 411 else 418 end, 'Fee ' || id, 1 from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 15)
    insert into app_products (id, club_id, active, product_type, name)
    select id, 418, 1, case when id % 2 = 0 then 'addon' else 'both' end, 'Product ' || id from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 300)
    insert into app_addons (id, addonable_id, addonable_type, addable_kind, addable_id, position)
    select id, ((id - 1) % 100) + 1, 'Event', case when id % 2 = 0 then 'Product' else 'Fee' end, ((id - 1) % 12) + 1, id % 3 from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 10)
    insert into app_custom_fields (id, club_id, position) select id, 418, id from seed;
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)
    insert into app_event_custom_fields (id, event_id, position) select id, ((id - 1) % 100) + 1, id % 5 from seed;
    insert into app_discounts (id, club_id, active) values (1, 418, 1), (2, 418, 1), (3, 418, 0);
    with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)
    insert into app_discount_items (id, item_id, item_type, discount_id) select id, ((id - 1) % 100) + 1, 'Event', ((id - 1) % 2) + 1 from seed;
    "
}

fn open_rusqlite_connection() -> rusqlite::Result<Connection> {
    let conn = Connection::open(DB_PATH)?;
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "busy_timeout", 5000)?;
    conn.pragma_update(None, "foreign_keys", "ON")?;
    Ok(conn)
}

fn seed_app_request_data_rusqlite() -> BenchResult<i64> {
    let conn = open_rusqlite_connection()?;
    conn.execute_batch(
        "
        drop table if exists app_users;
        drop table if exists app_clubs;
        drop table if exists app_events;
        drop table if exists app_sponsors;
        drop table if exists app_tags;
        drop table if exists app_taxes;
        drop table if exists app_fees;
        drop table if exists app_products;
        drop table if exists app_addons;
        drop table if exists app_custom_fields;
        drop table if exists app_event_custom_fields;
        drop table if exists app_discounts;
        drop table if exists app_discount_items;
        drop table if exists app_branding_palettes;
        drop table if exists app_admin_alerts;
        drop table if exists app_config_problems;

        create table app_users (id integer primary key, name text not null);
        create table app_clubs (id integer primary key, parent_id integer, subdomain text not null, province text not null);
        create index app_clubs_subdomain on app_clubs(subdomain);
        create index app_clubs_parent_id on app_clubs(parent_id);
        create table app_events (id integer primary key, club_id integer not null, name text not null, counter integer not null);
        create index app_events_club_id on app_events(club_id);
        create table app_sponsors (id integer primary key, club_id integer not null, name text not null);
        create index app_sponsors_club_id on app_sponsors(club_id);
        create table app_tags (id integer primary key, club_id integer not null, name text not null);
        create index app_tags_club_id on app_tags(club_id);
        create table app_taxes (id integer primary key, province text not null, name text not null);
        create index app_taxes_province on app_taxes(province);
        create table app_fees (id integer primary key, club_id integer not null, name text not null, active integer not null);
        create index app_fees_club_id on app_fees(club_id, active);
        create table app_products (id integer primary key, club_id integer not null, active integer not null, product_type text not null, name text not null);
        create index app_products_club_type on app_products(club_id, active, product_type);
        create table app_addons (id integer primary key, addonable_id integer not null, addonable_type text not null, addable_kind text not null, addable_id integer not null, position integer not null);
        create index app_addons_addonable on app_addons(addonable_id, addonable_type);
        create table app_custom_fields (id integer primary key, club_id integer not null, position integer not null);
        create index app_custom_fields_club_id on app_custom_fields(club_id);
        create table app_event_custom_fields (id integer primary key, event_id integer not null, position integer not null);
        create index app_event_custom_fields_event_id on app_event_custom_fields(event_id);
        create table app_discounts (id integer primary key, club_id integer not null, active integer not null);
        create index app_discounts_club_id on app_discounts(club_id, active);
        create table app_discount_items (id integer primary key, item_id integer not null, item_type text not null, discount_id integer not null);
        create index app_discount_items_item on app_discount_items(item_id, item_type);
        create table app_branding_palettes (id integer primary key, slug text not null);
        create table app_admin_alerts (id integer primary key, country text, club_type text);
        create table app_config_problems (id integer primary key, club_id integer not null, ignored integer not null);
        create index app_config_problems_club_id on app_config_problems(club_id, ignored);

        insert into app_users (id, name) values (1, 'Admin');
        insert into app_clubs (id, parent_id, subdomain, province) values
            (403, null, 'canada', 'ON'),
            (411, 403, 'ontario', 'ON'),
            (418, 411, 'demo', 'ON');
        insert into app_branding_palettes (id, slug) values (1, 'default');
        insert into app_admin_alerts (id, country, club_type) values (330, 'Canada', 'club');
        insert into app_config_problems (id, club_id, ignored) values (1, 418, 0);
        insert into app_taxes (id, province, name) values (1, 'ON', 'HST'), (2, 'ON', 'GST');

        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 100)
        insert into app_events (id, club_id, name, counter)
        select id, 418, 'Event ' || id, 0 from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 20)
        insert into app_sponsors (id, club_id, name) select id, 418, 'Sponsor ' || id from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 30)
        insert into app_tags (id, club_id, name) select id, 418, 'Tag ' || id from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 12)
        insert into app_fees (id, club_id, name, active)
        select id, case id % 3 when 0 then 403 when 1 then 411 else 418 end, 'Fee ' || id, 1 from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 15)
        insert into app_products (id, club_id, active, product_type, name)
        select id, 418, 1, case when id % 2 = 0 then 'addon' else 'both' end, 'Product ' || id from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 300)
        insert into app_addons (id, addonable_id, addonable_type, addable_kind, addable_id, position)
        select id, ((id - 1) % 100) + 1, 'Event', case when id % 2 = 0 then 'Product' else 'Fee' end, ((id - 1) % 12) + 1, id % 3 from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 10)
        insert into app_custom_fields (id, club_id, position) select id, 418, id from seed;
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)
        insert into app_event_custom_fields (id, event_id, position) select id, ((id - 1) % 100) + 1, id % 5 from seed;
        insert into app_discounts (id, club_id, active) values (1, 418, 1), (2, 418, 1), (3, 418, 0);
        with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)
        insert into app_discount_items (id, item_id, item_type, discount_id) select id, ((id - 1) % 100) + 1, 'Event', ((id - 1) % 2) + 1 from seed;
        ",
    )?;
    Ok(100)
}

fn admin_item_edit_requests_rusqlite(rows: i64) -> BenchResult<i64> {
    let conn = open_rusqlite_connection()?;
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_edit_request_rusqlite(&conn, event_id)?;
    }
    Ok(check)
}

fn one(conn: &Connection, sql: &str, params: &[&dyn rusqlite::ToSql]) -> rusqlite::Result<i64> {
    conn.query_row(sql, params, |row| row.get(0))
}

fn admin_item_edit_request_rusqlite(conn: &Connection, event_id: i64) -> BenchResult<i64> {
    let mut check = 0;
    check += one(conn, "select id from app_users where id = ?", &[&1_i64])?;
    check += one(
        conn,
        "select id from app_clubs where subdomain = ?",
        &[&"demo"],
    )?;
    check += one(
        conn,
        "select id from app_events where club_id = ? and id = ?",
        &[&418_i64, &event_id],
    )?;
    check += one(
        conn,
        "select count(*) from app_sponsors where club_id = ?",
        &[&418_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_tags where club_id = ?",
        &[&418_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_taxes where province = ?",
        &[&"ON"],
    )?;
    check += one(
        conn,
        "with recursive parents(id, parent_id) as (
            select id, parent_id from app_clubs where id = ?
            union all
            select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
        ) select coalesce(sum(id), 0) from parents",
        &[&418_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_fees where club_id in (?, ?, ?) and active = ?",
        &[&418_i64, &411_i64, &403_i64, &1_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)",
        &[&418_i64, &1_i64, &"addon", &"both"],
    )?;
    check += one(
        conn,
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
        &[&event_id, &"Event"],
    )?;

    for (sql, id) in [
        ("select id from app_fees where id = ?", 1_i64),
        ("select id from app_clubs where id = ?", 403_i64),
        ("select id from app_clubs where id = ?", 418_i64),
        ("select id from app_products where id = ?", 1_i64),
        ("select id from app_fees where id = ?", 2_i64),
    ] {
        check += one(conn, sql, &[&id])?;
    }

    check += one(
        conn,
        "select count(*) from app_custom_fields where club_id = ?",
        &[&418_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_event_custom_fields where event_id = ?",
        &[&event_id],
    )?;
    check += one(
        conn,
        "select count(*) from app_custom_fields where club_id = ?",
        &[&418_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_discounts where club_id = ? and active = ?",
        &[&418_i64, &1_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
        &[&event_id, &"Event"],
    )?;
    check += one(
        conn,
        "select count(*) from app_discounts where club_id = ? and active = ?",
        &[&418_i64, &1_i64],
    )?;
    check += one(
        conn,
        "select id from app_branding_palettes where id = ?",
        &[&1_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)",
        &[&"Canada", &"club"],
    )?;
    check += one(
        conn,
        "select count(*) from app_config_problems where club_id = ? and ignored = ?",
        &[&418_i64, &0_i64],
    )?;
    check += one(
        conn,
        "select count(*) from app_events where club_id = ?",
        &[&418_i64],
    )?;
    check += one(
        conn,
        "select counter from app_events where id = ?",
        &[&event_id],
    )?;
    Ok(check)
}

fn admin_item_update_requests_rusqlite(rows: i64) -> BenchResult<i64> {
    let mut conn = open_rusqlite_connection()?;
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_update_request_rusqlite(&mut conn, i, event_id)?;
    }
    Ok(check)
}

fn admin_item_update_request_rusqlite(
    conn: &mut Connection,
    sequence: i64,
    event_id: i64,
) -> BenchResult<i64> {
    let tx = conn.transaction()?;
    let mut check = 0;
    check += one(&tx, "select id from app_users where id = ?", &[&1_i64])?;
    check += one(
        &tx,
        "select id from app_clubs where subdomain = ?",
        &[&"demo"],
    )?;
    check += one(
        &tx,
        "select id from app_events where club_id = ? and id = ?",
        &[&418_i64, &event_id],
    )?;
    check += one(
        &tx,
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
        &[&event_id, &"Event"],
    )?;
    check += one(
        &tx,
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
        &[&event_id, &"Event"],
    )?;
    check += one(
        &tx,
        "select count(*) from app_tags where club_id = ?",
        &[&418_i64],
    )?;
    tx.execute(
        "update app_events set counter = counter + 1, name = ? where id = ?",
        rusqlite::params![format!("Updated Event {sequence}"), event_id],
    )?;
    tx.commit()?;
    Ok(check + event_id)
}

async fn admin_item_edit_requests(pool: &SqlitePool, rows: i64) -> BenchResult<i64> {
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_edit_request(pool, event_id).await?;
    }
    Ok(check)
}

async fn admin_item_edit_request(pool: &SqlitePool, event_id: i64) -> BenchResult<i64> {
    let mut check = 0;
    check += sqlx::query_scalar::<_, i64>("select id from app_users where id = ?")
        .bind(1_i64)
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_clubs where subdomain = ?")
        .bind("demo")
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_events where club_id = ? and id = ?")
        .bind(418_i64)
        .bind(event_id)
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_sponsors where club_id = ?")
        .bind(418_i64)
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_tags where club_id = ?")
        .bind(418_i64)
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_taxes where province = ?")
        .bind("ON")
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>(
        "with recursive parents(id, parent_id) as (
            select id, parent_id from app_clubs where id = ?
            union all
            select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
        ) select coalesce(sum(id), 0) from parents",
    )
    .bind(418_i64)
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_fees where club_id in (?, ?, ?) and active = ?",
    )
    .bind(418_i64)
    .bind(411_i64)
    .bind(403_i64)
    .bind(1_i64)
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)",
    )
    .bind(418_i64)
    .bind(1_i64)
    .bind("addon")
    .bind("both")
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(pool)
    .await?;

    for (sql, id) in [
        ("select id from app_fees where id = ?", 1_i64),
        ("select id from app_clubs where id = ?", 403_i64),
        ("select id from app_clubs where id = ?", 418_i64),
        ("select id from app_products where id = ?", 1_i64),
        ("select id from app_fees where id = ?", 2_i64),
    ] {
        check += sqlx::query_scalar::<_, i64>(sql)
            .bind(id)
            .fetch_one(pool)
            .await?;
    }

    check +=
        sqlx::query_scalar::<_, i64>("select count(*) from app_custom_fields where club_id = ?")
            .bind(418_i64)
            .fetch_one(pool)
            .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_event_custom_fields where event_id = ?",
    )
    .bind(event_id)
    .fetch_one(pool)
    .await?;
    check +=
        sqlx::query_scalar::<_, i64>("select count(*) from app_custom_fields where club_id = ?")
            .bind(418_i64)
            .fetch_one(pool)
            .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discounts where club_id = ? and active = ?",
    )
    .bind(418_i64)
    .bind(1_i64)
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discounts where club_id = ? and active = ?",
    )
    .bind(418_i64)
    .bind(1_i64)
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_branding_palettes where id = ?")
        .bind(1_i64)
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)",
    )
    .bind("Canada")
    .bind("club")
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_config_problems where club_id = ? and ignored = ?",
    )
    .bind(418_i64)
    .bind(0_i64)
    .fetch_one(pool)
    .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_events where club_id = ?")
        .bind(418_i64)
        .fetch_one(pool)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select counter from app_events where id = ?")
        .bind(event_id)
        .fetch_one(pool)
        .await?;
    Ok(check)
}

async fn admin_item_update_requests(pool: &SqlitePool, rows: i64) -> BenchResult<i64> {
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_update_request(pool, i, event_id).await?;
    }
    Ok(check)
}

async fn admin_item_update_request(
    pool: &SqlitePool,
    sequence: i64,
    event_id: i64,
) -> BenchResult<i64> {
    let mut tx = pool.begin().await?;
    let mut check = 0;
    check += sqlx::query_scalar::<_, i64>("select id from app_users where id = ?")
        .bind(1_i64)
        .fetch_one(&mut *tx)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_clubs where subdomain = ?")
        .bind("demo")
        .fetch_one(&mut *tx)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_events where club_id = ? and id = ?")
        .bind(418_i64)
        .bind(event_id)
        .fetch_one(&mut *tx)
        .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(&mut *tx)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(&mut *tx)
    .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_tags where club_id = ?")
        .bind(418_i64)
        .fetch_one(&mut *tx)
        .await?;

    sqlx::query("update app_events set counter = counter + 1, name = ? where id = ?")
        .bind(format!("Updated Event {sequence}"))
        .bind(event_id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok(check + event_id)
}

async fn admin_item_edit_requests_conn(conn: &mut SqliteConnection, rows: i64) -> BenchResult<i64> {
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_edit_request_conn(conn, event_id).await?;
    }
    Ok(check)
}

async fn admin_item_edit_request_conn(
    conn: &mut SqliteConnection,
    event_id: i64,
) -> BenchResult<i64> {
    let mut check = 0;
    check += sqlx::query_scalar::<_, i64>("select id from app_users where id = ?")
        .bind(1_i64)
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_clubs where subdomain = ?")
        .bind("demo")
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_events where club_id = ? and id = ?")
        .bind(418_i64)
        .bind(event_id)
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_sponsors where club_id = ?")
        .bind(418_i64)
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_tags where club_id = ?")
        .bind(418_i64)
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_taxes where province = ?")
        .bind("ON")
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>(
        "with recursive parents(id, parent_id) as (
            select id, parent_id from app_clubs where id = ?
            union all
            select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
        ) select coalesce(sum(id), 0) from parents",
    )
    .bind(418_i64)
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_fees where club_id in (?, ?, ?) and active = ?",
    )
    .bind(418_i64)
    .bind(411_i64)
    .bind(403_i64)
    .bind(1_i64)
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)",
    )
    .bind(418_i64)
    .bind(1_i64)
    .bind("addon")
    .bind("both")
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(&mut *conn)
    .await?;

    for (sql, id) in [
        ("select id from app_fees where id = ?", 1_i64),
        ("select id from app_clubs where id = ?", 403_i64),
        ("select id from app_clubs where id = ?", 418_i64),
        ("select id from app_products where id = ?", 1_i64),
        ("select id from app_fees where id = ?", 2_i64),
    ] {
        check += sqlx::query_scalar::<_, i64>(sql)
            .bind(id)
            .fetch_one(&mut *conn)
            .await?;
    }

    check +=
        sqlx::query_scalar::<_, i64>("select count(*) from app_custom_fields where club_id = ?")
            .bind(418_i64)
            .fetch_one(&mut *conn)
            .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_event_custom_fields where event_id = ?",
    )
    .bind(event_id)
    .fetch_one(&mut *conn)
    .await?;
    check +=
        sqlx::query_scalar::<_, i64>("select count(*) from app_custom_fields where club_id = ?")
            .bind(418_i64)
            .fetch_one(&mut *conn)
            .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discounts where club_id = ? and active = ?",
    )
    .bind(418_i64)
    .bind(1_i64)
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discounts where club_id = ? and active = ?",
    )
    .bind(418_i64)
    .bind(1_i64)
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_branding_palettes where id = ?")
        .bind(1_i64)
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)",
    )
    .bind("Canada")
    .bind("club")
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_config_problems where club_id = ? and ignored = ?",
    )
    .bind(418_i64)
    .bind(0_i64)
    .fetch_one(&mut *conn)
    .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_events where club_id = ?")
        .bind(418_i64)
        .fetch_one(&mut *conn)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select counter from app_events where id = ?")
        .bind(event_id)
        .fetch_one(&mut *conn)
        .await?;
    Ok(check)
}

async fn admin_item_update_requests_conn(
    conn: &mut SqliteConnection,
    rows: i64,
) -> BenchResult<i64> {
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_update_request_conn(conn, i, event_id).await?;
    }
    Ok(check)
}

async fn admin_item_update_request_conn(
    conn: &mut SqliteConnection,
    sequence: i64,
    event_id: i64,
) -> BenchResult<i64> {
    let mut tx = SqlxConnection::begin(conn).await?;
    let mut check = 0;
    check += sqlx::query_scalar::<_, i64>("select id from app_users where id = ?")
        .bind(1_i64)
        .fetch_one(&mut *tx)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_clubs where subdomain = ?")
        .bind("demo")
        .fetch_one(&mut *tx)
        .await?;
    check += sqlx::query_scalar::<_, i64>("select id from app_events where club_id = ? and id = ?")
        .bind(418_i64)
        .bind(event_id)
        .fetch_one(&mut *tx)
        .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(&mut *tx)
    .await?;
    check += sqlx::query_scalar::<_, i64>(
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
    )
    .bind(event_id)
    .bind("Event")
    .fetch_one(&mut *tx)
    .await?;
    check += sqlx::query_scalar::<_, i64>("select count(*) from app_tags where club_id = ?")
        .bind(418_i64)
        .fetch_one(&mut *tx)
        .await?;

    sqlx::query("update app_events set counter = counter + 1, name = ? where id = ?")
        .bind(format!("Updated Event {sequence}"))
        .bind(event_id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok(check + event_id)
}

async fn admin_item_update_requests_conn_manual_tx(
    conn: &mut SqliteConnection,
    rows: i64,
) -> BenchResult<i64> {
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_update_request_conn_manual_tx(conn, i, event_id).await?;
    }
    Ok(check)
}

async fn admin_item_update_request_conn_manual_tx(
    conn: &mut SqliteConnection,
    sequence: i64,
    event_id: i64,
) -> BenchResult<i64> {
    sqlx::query("begin transaction").execute(&mut *conn).await?;
    let result = async {
        let mut check = 0;
        check += sqlx::query_scalar::<_, i64>("select id from app_users where id = ?")
            .bind(1_i64)
            .fetch_one(&mut *conn)
            .await?;
        check += sqlx::query_scalar::<_, i64>("select id from app_clubs where subdomain = ?")
            .bind("demo")
            .fetch_one(&mut *conn)
            .await?;
        check +=
            sqlx::query_scalar::<_, i64>("select id from app_events where club_id = ? and id = ?")
                .bind(418_i64)
                .bind(event_id)
                .fetch_one(&mut *conn)
                .await?;
        check += sqlx::query_scalar::<_, i64>(
            "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
        )
        .bind(event_id)
        .bind("Event")
        .fetch_one(&mut *conn)
        .await?;
        check += sqlx::query_scalar::<_, i64>(
            "select count(*) from app_discount_items where item_id = ? and item_type = ?",
        )
        .bind(event_id)
        .bind("Event")
        .fetch_one(&mut *conn)
        .await?;
        check += sqlx::query_scalar::<_, i64>("select count(*) from app_tags where club_id = ?")
            .bind(418_i64)
            .fetch_one(&mut *conn)
            .await?;

        sqlx::query("update app_events set counter = counter + 1, name = ? where id = ?")
            .bind(format!("Updated Event {sequence}"))
            .bind(event_id)
            .execute(&mut *conn)
            .await?;
        Ok::<i64, Box<dyn Error + Send + Sync>>(check + event_id)
    }
    .await;

    match result {
        Ok(check) => {
            sqlx::query("commit").execute(&mut *conn).await?;
            Ok(check)
        }
        Err(error) => {
            let _ = sqlx::query("rollback").execute(&mut *conn).await;
            Err(error)
        }
    }
}
