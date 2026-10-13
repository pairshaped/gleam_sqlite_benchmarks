use rusqlite::Connection;
use std::error::Error;
use std::fs;
use std::io;
use std::sync::{Barrier, OnceLock};
use std::thread;
use std::time::{Duration, Instant};

type BenchResult<T> = Result<T, Box<dyn Error + Send + Sync>>;

const DEFAULT_ROW_COUNT: i64 = 5_000;
const DB_PATH: &str = "rust_benchmark.sqlite3";
// rusqlite's default statement cache holds 16 statements. The edit request
// cycles through 22, which evicts every statement before its next use.
const STATEMENT_CACHE_CAPACITY: usize = 256;

fn main() -> BenchResult<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.get(1).map(String::as_str) == Some("concurrent") {
        return concurrent_main(&args);
    }

    let rows = row_count_from_args();
    remove_sqlite_files(DB_PATH)?;

    println!("case,items,micros,us_per_item,check");

    measure_sync("rust_rusqlite/app_request/seed_dummy_data", 1, || {
        seed_app_request_data_rusqlite()
    })?;
    measure_sync("rust_rusqlite/app_request/admin_item_edit", rows, || {
        admin_item_edit_requests_rusqlite(rows)
    })?;
    measure_sync(
        "rust_rusqlite_query_only/app_request/admin_item_edit",
        rows,
        || admin_item_edit_requests_rusqlite_query_only(rows),
    )?;
    measure_sync("rust_rusqlite/app_request/admin_item_update", rows, || {
        admin_item_update_requests_rusqlite(rows)
    })?;

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

fn open_rusqlite_connection() -> rusqlite::Result<Connection> {
    let conn = Connection::open(DB_PATH)?;
    // Set the busy timeout before anything that takes a lock, so connections
    // opened at the same moment wait for each other instead of failing.
    conn.busy_timeout(Duration::from_millis(5000))?;
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    conn.pragma_update(None, "foreign_keys", "ON")?;
    conn.set_prepared_statement_cache_capacity(STATEMENT_CACHE_CAPACITY);
    Ok(conn)
}

fn open_rusqlite_query_only_connection() -> rusqlite::Result<Connection> {
    let conn = open_rusqlite_connection()?;
    conn.pragma_update(None, "query_only", "ON")?;
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

fn admin_item_edit_requests_rusqlite_query_only(rows: i64) -> BenchResult<i64> {
    let conn = open_rusqlite_query_only_connection()?;
    assert_query_only_blocks_writes(&conn)?;

    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_edit_request_rusqlite(&conn, event_id)?;
    }
    Ok(check)
}

fn assert_query_only_blocks_writes(conn: &Connection) -> BenchResult<()> {
    match conn.execute(
        "insert into app_users (id, name) values (?, ?)",
        (999_i64, "Blocked"),
    ) {
        Err(rusqlite::Error::SqliteFailure(error, _))
            if error.code == rusqlite::ErrorCode::ReadOnly =>
        {
            Ok(())
        }
        Err(error) => Err(Box::new(error)),
        Ok(_) => Err("query_only connection allowed a write".into()),
    }
}

fn one(conn: &Connection, sql: &str, params: &[&dyn rusqlite::ToSql]) -> rusqlite::Result<i64> {
    conn.prepare_cached(sql)?
        .query_row(params, |row| row.get(0))
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
    let conn = open_rusqlite_connection()?;
    let mut check = 0;
    for i in 1..=rows {
        let event_id = ((i - 1) % 100) + 1;
        check += admin_item_update_request_rusqlite(&conn, "begin", i, event_id)?;
    }
    Ok(check)
}

/// `begin` is "begin" for the sequential case and "begin immediate" when several
/// workers write at once (see `run_concurrent`).
fn admin_item_update_request_rusqlite(
    conn: &Connection,
    begin: &str,
    sequence: i64,
    event_id: i64,
) -> BenchResult<i64> {
    // `Connection::transaction` sends BEGIN and COMMIT through `execute_batch`,
    // which parses them again on every request. Run them as cached statements
    // so every statement in the request comes from the cache, like the other
    // runners.
    conn.prepare_cached(begin)?.execute([])?;
    let result = (|| -> BenchResult<i64> {
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
            "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
            &[&event_id, &"Event"],
        )?;
        check += one(
            conn,
            "select count(*) from app_discount_items where item_id = ? and item_type = ?",
            &[&event_id, &"Event"],
        )?;
        check += one(
            conn,
            "select count(*) from app_tags where club_id = ?",
            &[&418_i64],
        )?;
        conn.prepare_cached("update app_events set counter = counter + 1, name = ? where id = ?")?
            .execute(rusqlite::params![
                format!("Updated Event {sequence}"),
                event_id
            ])?;
        Ok(check)
    })();
    match result {
        Ok(check) => {
            conn.prepare_cached("commit")?.execute([])?;
            Ok(check + event_id)
        }
        Err(error) => {
            let _ = conn.execute_batch("rollback");
            Err(error)
        }
    }
}

// Concurrent mode: W workers, each with its own connection and statement cache,
// run one workload for a fixed time. Every worker opens its connection before
// the clock starts, warms up, then records the latency of each request that
// starts inside the measured window. Writes use BEGIN IMMEDIATE: a deferred
// transaction that reads and then writes fails at once with SQLITE_BUSY if
// another worker committed in between, without waiting on busy_timeout.

#[derive(Clone, Copy)]
enum Workload {
    Read,
    Write,
    Mixed,
}

impl Workload {
    fn name(self) -> &'static str {
        match self {
            Workload::Read => "read",
            Workload::Write => "write",
            Workload::Mixed => "mixed",
        }
    }
}

/// Usage: sqlite_tests_rust concurrent <duration seconds> <warmup seconds> <workers,...>
fn concurrent_main(args: &[String]) -> BenchResult<()> {
    let [_, _, duration, warmup, workers] = args else {
        return Err("usage: concurrent <duration> <warmup> <workers,...>".into());
    };
    let duration: f64 = duration.parse()?;
    let warmup: f64 = warmup.parse()?;
    let workers: Vec<usize> = workers
        .split(',')
        .map(str::parse)
        .collect::<Result<_, _>>()?;

    remove_sqlite_files(DB_PATH)?;
    seed_app_request_data_rusqlite()?;
    println!(
        "case,workers,seconds,requests,requests_per_second,p50_us,p95_us,p99_us,max_us,errors"
    );
    for workload in [Workload::Read, Workload::Write, Workload::Mixed] {
        for &count in &workers {
            run_concurrent(workload, count, duration, warmup)?;
        }
    }
    Ok(())
}

fn is_busy(error: &(dyn Error + Send + Sync + 'static)) -> bool {
    error
        .downcast_ref::<rusqlite::Error>()
        .and_then(rusqlite::Error::sqlite_error_code)
        == Some(rusqlite::ErrorCode::DatabaseBusy)
}

fn run_concurrent(
    workload: Workload,
    workers: usize,
    duration: f64,
    warmup: f64,
) -> BenchResult<()> {
    let ready = Barrier::new(workers + 1);
    let go = Barrier::new(workers + 1);
    let deadlines: OnceLock<(Instant, Instant)> = OnceLock::new();

    let (latencies, errors) = thread::scope(|scope| -> BenchResult<(Vec<u64>, u64)> {
        let handles: Vec<_> = (0..workers)
            .map(|index| {
                let (ready, go, deadlines) = (&ready, &go, &deadlines);
                scope.spawn(move || -> BenchResult<(Vec<u64>, u64)> {
                    let conn = open_rusqlite_connection()?;
                    ready.wait();
                    go.wait();
                    let (warm_until, measure_until) = *deadlines.get().expect("deadlines set");

                    let mut latencies = Vec::with_capacity(65_536);
                    let mut errors = 0;
                    // Offset each worker's event ids so workers don't all hit the same rows.
                    let mut sequence = index as i64 * 37;
                    loop {
                        let start = Instant::now();
                        if start >= measure_until {
                            break;
                        }
                        sequence += 1;
                        let event_id = ((sequence - 1) % 100) + 1;
                        let write = match workload {
                            Workload::Read => false,
                            Workload::Write => true,
                            Workload::Mixed => sequence % 10 == 0,
                        };
                        if write {
                            match admin_item_update_request_rusqlite(
                                &conn,
                                "begin immediate",
                                sequence,
                                event_id,
                            ) {
                                Ok(_) => {}
                                // The busy timeout expired before the write lock
                                // was free. Count it, during warm-up too, as the
                                // Gleam runner does; anything else stops the run.
                                Err(error) if is_busy(error.as_ref()) => {
                                    errors += 1;
                                    continue;
                                }
                                Err(error) => return Err(error),
                            }
                        } else {
                            admin_item_edit_request_rusqlite(&conn, event_id)?;
                        }
                        if start >= warm_until {
                            latencies.push(start.elapsed().as_micros() as u64);
                        }
                    }
                    Ok((latencies, errors))
                })
            })
            .collect();

        ready.wait();
        let warm_until = Instant::now() + Duration::from_secs_f64(warmup);
        deadlines
            .set((warm_until, warm_until + Duration::from_secs_f64(duration)))
            .expect("deadlines set once");
        go.wait();

        let mut all = Vec::new();
        let mut errors = 0;
        for handle in handles {
            let (latencies, worker_errors) = handle.join().expect("worker panicked")?;
            all.extend(latencies);
            errors += worker_errors;
        }
        Ok((all, errors))
    })?;

    let mut latencies = latencies;
    latencies.sort_unstable();
    let percentile = |p: f64| {
        if latencies.is_empty() {
            0
        } else {
            latencies[((latencies.len() - 1) as f64 * p) as usize]
        }
    };
    let total = latencies.len();
    // Errors are writes whose busy timeout expired; anything else stops the runner.
    println!(
        "rust_rusqlite/concurrent/{},{workers},{duration},{total},{:.0},{},{},{},{},{errors}",
        workload.name(),
        total as f64 / duration,
        percentile(0.50),
        percentile(0.95),
        percentile(0.99),
        latencies.last().copied().unwrap_or(0),
    );
    Ok(())
}
