// Zig calling the SQLite C API directly, the usual way Zig code uses SQLite.
// Each connection prepares its statements once and reuses them.

const std = @import("std");

const c = @cImport({
    @cInclude("sqlite3.h");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("time.h");
    @cInclude("unistd.h");
});

const default_row_count: i64 = 5000;
const db_path = "zig_benchmark.sqlite3";

const seed_sql =
    \\drop table if exists app_users;
    \\drop table if exists app_clubs;
    \\drop table if exists app_events;
    \\drop table if exists app_sponsors;
    \\drop table if exists app_tags;
    \\drop table if exists app_taxes;
    \\drop table if exists app_fees;
    \\drop table if exists app_products;
    \\drop table if exists app_addons;
    \\drop table if exists app_custom_fields;
    \\drop table if exists app_event_custom_fields;
    \\drop table if exists app_discounts;
    \\drop table if exists app_discount_items;
    \\drop table if exists app_branding_palettes;
    \\drop table if exists app_admin_alerts;
    \\drop table if exists app_config_problems;
    \\create table app_users (id integer primary key, name text not null);
    \\create table app_clubs (id integer primary key, parent_id integer, subdomain text not null, province text not null);
    \\create index app_clubs_subdomain on app_clubs(subdomain);
    \\create index app_clubs_parent_id on app_clubs(parent_id);
    \\create table app_events (id integer primary key, club_id integer not null, name text not null, counter integer not null);
    \\create index app_events_club_id on app_events(club_id);
    \\create table app_sponsors (id integer primary key, club_id integer not null, name text not null);
    \\create index app_sponsors_club_id on app_sponsors(club_id);
    \\create table app_tags (id integer primary key, club_id integer not null, name text not null);
    \\create index app_tags_club_id on app_tags(club_id);
    \\create table app_taxes (id integer primary key, province text not null, name text not null);
    \\create index app_taxes_province on app_taxes(province);
    \\create table app_fees (id integer primary key, club_id integer not null, name text not null, active integer not null);
    \\create index app_fees_club_id on app_fees(club_id, active);
    \\create table app_products (id integer primary key, club_id integer not null, active integer not null, product_type text not null, name text not null);
    \\create index app_products_club_type on app_products(club_id, active, product_type);
    \\create table app_addons (id integer primary key, addonable_id integer not null, addonable_type text not null, addable_kind text not null, addable_id integer not null, position integer not null);
    \\create index app_addons_addonable on app_addons(addonable_id, addonable_type);
    \\create table app_custom_fields (id integer primary key, club_id integer not null, position integer not null);
    \\create index app_custom_fields_club_id on app_custom_fields(club_id);
    \\create table app_event_custom_fields (id integer primary key, event_id integer not null, position integer not null);
    \\create index app_event_custom_fields_event_id on app_event_custom_fields(event_id);
    \\create table app_discounts (id integer primary key, club_id integer not null, active integer not null);
    \\create index app_discounts_club_id on app_discounts(club_id, active);
    \\create table app_discount_items (id integer primary key, item_id integer not null, item_type text not null, discount_id integer not null);
    \\create index app_discount_items_item on app_discount_items(item_id, item_type);
    \\create table app_branding_palettes (id integer primary key, slug text not null);
    \\create table app_admin_alerts (id integer primary key, country text, club_type text);
    \\create table app_config_problems (id integer primary key, club_id integer not null, ignored integer not null);
    \\create index app_config_problems_club_id on app_config_problems(club_id, ignored);
    \\insert into app_users (id, name) values (1, 'Admin');
    \\insert into app_clubs (id, parent_id, subdomain, province) values
    \\  (403, null, 'canada', 'ON'), (411, 403, 'ontario', 'ON'), (418, 411, 'demo', 'ON');
    \\insert into app_branding_palettes (id, slug) values (1, 'default');
    \\insert into app_admin_alerts (id, country, club_type) values (330, 'Canada', 'club');
    \\insert into app_config_problems (id, club_id, ignored) values (1, 418, 0);
    \\insert into app_taxes (id, province, name) values (1, 'ON', 'HST'), (2, 'ON', 'GST');
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 100)
    \\insert into app_events (id, club_id, name, counter) select id, 418, 'Event ' || id, 0 from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 20)
    \\insert into app_sponsors (id, club_id, name) select id, 418, 'Sponsor ' || id from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 30)
    \\insert into app_tags (id, club_id, name) select id, 418, 'Tag ' || id from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 12)
    \\insert into app_fees (id, club_id, name, active)
    \\select id, case id % 3 when 0 then 403 when 1 then 411 else 418 end, 'Fee ' || id, 1 from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 15)
    \\insert into app_products (id, club_id, active, product_type, name)
    \\select id, 418, 1, case when id % 2 = 0 then 'addon' else 'both' end, 'Product ' || id from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 300)
    \\insert into app_addons (id, addonable_id, addonable_type, addable_kind, addable_id, position)
    \\select id, ((id - 1) % 100) + 1, 'Event', case when id % 2 = 0 then 'Product' else 'Fee' end, ((id - 1) % 12) + 1, id % 3 from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 10)
    \\insert into app_custom_fields (id, club_id, position) select id, 418, id from seed;
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)
    \\insert into app_event_custom_fields (id, event_id, position) select id, ((id - 1) % 100) + 1, id % 5 from seed;
    \\insert into app_discounts (id, club_id, active) values (1, 418, 1), (2, 418, 1), (3, 418, 0);
    \\with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)
    \\insert into app_discount_items (id, item_id, item_type, discount_id) select id, ((id - 1) % 100) + 1, 'Event', ((id - 1) % 2) + 1 from seed;
;

/// The statements the edit and update requests use, prepared once per connection.
const Statement = enum {
    user,
    club_by_subdomain,
    event,
    sponsors,
    tags,
    taxes,
    parent_chain,
    fees,
    products,
    addons,
    fee_id,
    club_id,
    product_id,
    custom_fields,
    event_custom_fields,
    discounts,
    discount_items,
    branding_palette,
    admin_alerts,
    config_problems,
    events,
    event_counter,
    update_event,
    begin,
    begin_immediate,
    commit,

    fn sql(self: Statement) [:0]const u8 {
        return switch (self) {
            .user => "select id from app_users where id = ?",
            .club_by_subdomain => "select id from app_clubs where subdomain = ?",
            .event => "select id from app_events where club_id = ? and id = ?",
            .sponsors => "select count(*) from app_sponsors where club_id = ?",
            .tags => "select count(*) from app_tags where club_id = ?",
            .taxes => "select count(*) from app_taxes where province = ?",
            .parent_chain =>
            \\with recursive parents(id, parent_id) as (
            \\  select id, parent_id from app_clubs where id = ?
            \\  union all
            \\  select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
            \\) select coalesce(sum(id), 0) from parents
            ,
            .fees => "select count(*) from app_fees where club_id in (?, ?, ?) and active = ?",
            .products => "select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)",
            .addons => "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
            .fee_id => "select id from app_fees where id = ?",
            .club_id => "select id from app_clubs where id = ?",
            .product_id => "select id from app_products where id = ?",
            .custom_fields => "select count(*) from app_custom_fields where club_id = ?",
            .event_custom_fields => "select count(*) from app_event_custom_fields where event_id = ?",
            .discounts => "select count(*) from app_discounts where club_id = ? and active = ?",
            .discount_items => "select count(*) from app_discount_items where item_id = ? and item_type = ?",
            .branding_palette => "select id from app_branding_palettes where id = ?",
            .admin_alerts => "select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)",
            .config_problems => "select count(*) from app_config_problems where club_id = ? and ignored = ?",
            .events => "select count(*) from app_events where club_id = ?",
            .event_counter => "select counter from app_events where id = ?",
            .update_event => "update app_events set counter = counter + 1, name = ? where id = ?",
            .begin => "begin",
            .begin_immediate => "begin immediate",
            .commit => "commit",
        };
    }
};

const statement_count = @typeInfo(Statement).@"enum".fields.len;

/// A bound parameter: an integer, text, or the request's event id.
const Param = union(enum) {
    int: i64,
    text: [:0]const u8,
    event_id,
};

const Query = struct {
    statement: Statement,
    params: []const Param,
};

const edit_queries = [_]Query{
    .{ .statement = .user, .params = &.{.{ .int = 1 }} },
    .{ .statement = .club_by_subdomain, .params = &.{.{ .text = "demo" }} },
    .{ .statement = .event, .params = &.{ .{ .int = 418 }, .event_id } },
    .{ .statement = .sponsors, .params = &.{.{ .int = 418 }} },
    .{ .statement = .tags, .params = &.{.{ .int = 418 }} },
    .{ .statement = .taxes, .params = &.{.{ .text = "ON" }} },
    .{ .statement = .parent_chain, .params = &.{.{ .int = 418 }} },
    .{ .statement = .fees, .params = &.{ .{ .int = 418 }, .{ .int = 411 }, .{ .int = 403 }, .{ .int = 1 } } },
    .{ .statement = .products, .params = &.{ .{ .int = 418 }, .{ .int = 1 }, .{ .text = "addon" }, .{ .text = "both" } } },
    .{ .statement = .addons, .params = &.{ .event_id, .{ .text = "Event" } } },
    .{ .statement = .fee_id, .params = &.{.{ .int = 1 }} },
    .{ .statement = .club_id, .params = &.{.{ .int = 403 }} },
    .{ .statement = .club_id, .params = &.{.{ .int = 418 }} },
    .{ .statement = .product_id, .params = &.{.{ .int = 1 }} },
    .{ .statement = .fee_id, .params = &.{.{ .int = 2 }} },
    .{ .statement = .custom_fields, .params = &.{.{ .int = 418 }} },
    .{ .statement = .event_custom_fields, .params = &.{.event_id} },
    .{ .statement = .custom_fields, .params = &.{.{ .int = 418 }} },
    .{ .statement = .discounts, .params = &.{ .{ .int = 418 }, .{ .int = 1 } } },
    .{ .statement = .discount_items, .params = &.{ .event_id, .{ .text = "Event" } } },
    .{ .statement = .discounts, .params = &.{ .{ .int = 418 }, .{ .int = 1 } } },
    .{ .statement = .branding_palette, .params = &.{.{ .int = 1 }} },
    .{ .statement = .admin_alerts, .params = &.{ .{ .text = "Canada" }, .{ .text = "club" } } },
    .{ .statement = .config_problems, .params = &.{ .{ .int = 418 }, .{ .int = 0 } } },
    .{ .statement = .events, .params = &.{.{ .int = 418 }} },
    .{ .statement = .event_counter, .params = &.{.event_id} },
};

const update_queries = [_]Query{
    .{ .statement = .user, .params = &.{.{ .int = 1 }} },
    .{ .statement = .club_by_subdomain, .params = &.{.{ .text = "demo" }} },
    .{ .statement = .event, .params = &.{ .{ .int = 418 }, .event_id } },
    .{ .statement = .addons, .params = &.{ .event_id, .{ .text = "Event" } } },
    .{ .statement = .discount_items, .params = &.{ .event_id, .{ .text = "Event" } } },
    .{ .statement = .tags, .params = &.{.{ .int = 418 }} },
};

const Connection = struct {
    db: *c.sqlite3,
    statements: [statement_count]*c.sqlite3_stmt,

    fn open() Connection {
        var db: ?*c.sqlite3 = null;
        check(db, c.sqlite3_open(db_path, &db), "open");
        const handle = db.?;
        // Set the busy timeout before anything that takes a lock, so connections
        // opened at the same moment wait for each other instead of failing.
        check(handle, c.sqlite3_busy_timeout(handle, 5000), "busy_timeout");
        check(handle, c.sqlite3_exec(handle,
            \\pragma journal_mode = WAL;
            \\pragma synchronous = NORMAL;
            \\pragma foreign_keys = ON;
        , null, null, null), "pragmas");
        return .{ .db = handle, .statements = undefined };
    }

    fn prepareAll(self: *Connection) void {
        inline for (@typeInfo(Statement).@"enum".fields, 0..) |field, i| {
            const statement: Statement = @enumFromInt(field.value);
            var handle: ?*c.sqlite3_stmt = null;
            check(self.db, c.sqlite3_prepare_v3(self.db, statement.sql().ptr, -1, c.SQLITE_PREPARE_PERSISTENT, &handle, null), field.name);
            self.statements[i] = handle.?;
        }
    }

    fn close(self: *Connection) void {
        for (self.statements) |statement| _ = c.sqlite3_finalize(statement);
        _ = c.sqlite3_close(self.db);
    }

    fn get(self: *Connection, statement: Statement) *c.sqlite3_stmt {
        return self.statements[@intFromEnum(statement)];
    }

    fn one(self: *Connection, query: Query, event_id: i64) i64 {
        const statement = self.get(query.statement);
        for (query.params, 1..) |param, index| {
            const position: c_int = @intCast(index);
            const rc = switch (param) {
                .int => |value| c.sqlite3_bind_int64(statement, position, value),
                .text => |value| c.sqlite3_bind_text(statement, position, value.ptr, @intCast(value.len), null),
                .event_id => c.sqlite3_bind_int64(statement, position, event_id),
            };
            check(self.db, rc, "bind");
        }
        if (c.sqlite3_step(statement) != c.SQLITE_ROW) fail(self.db, query.statement.sql());
        const value = c.sqlite3_column_int64(statement, 0);
        _ = c.sqlite3_reset(statement);
        return value;
    }

    fn run(self: *Connection, statement: *c.sqlite3_stmt) void {
        if (c.sqlite3_step(statement) != c.SQLITE_DONE) fail(self.db, "step");
        _ = c.sqlite3_reset(statement);
    }
};

fn check(db: ?*c.sqlite3, rc: c_int, what: [*:0]const u8) void {
    if (rc != c.SQLITE_OK) fail(db, what);
}

fn fail(db: ?*c.sqlite3, what: [*:0]const u8) noreturn {
    const message: [*:0]const u8 = if (db) |handle| c.sqlite3_errmsg(handle) else "unknown error";
    _ = c.dprintf(2, "%s failed: %s\n", what, message);
    c.exit(1);
}

fn seedAppRequestData(rows: i64) i64 {
    _ = rows;
    const conn = Connection.open();
    check(conn.db, c.sqlite3_exec(conn.db, seed_sql, null, null, null), "seed");
    _ = c.sqlite3_close(conn.db);
    return 100;
}

fn editRequest(conn: *Connection, event_id: i64) i64 {
    var check_sum: i64 = 0;
    for (edit_queries) |query| check_sum += conn.one(query, event_id);
    return check_sum;
}

/// `begin` is `.begin` for the sequential case and `.begin_immediate` when
/// several workers write at once (see runConcurrent).
fn updateRequest(conn: *Connection, begin: Statement, sequence: i64, event_id: i64) i64 {
    var check_sum: i64 = 0;
    var name: [64]u8 = undefined;
    conn.run(conn.get(begin));
    for (update_queries) |query| check_sum += conn.one(query, event_id);
    const length = c.snprintf(&name, name.len, "Updated Event %lld", @as(c_longlong, sequence));
    const update = conn.get(.update_event);
    // The buffer outlives the step that reads it, so SQLite needn't copy it.
    check(conn.db, c.sqlite3_bind_text(update, 1, &name, length, null), "bind");
    check(conn.db, c.sqlite3_bind_int64(update, 2, event_id), "bind");
    conn.run(update);
    conn.run(conn.get(.commit));
    return check_sum + event_id;
}

fn adminItemEditRequests(rows: i64) i64 {
    var conn = Connection.open();
    conn.prepareAll();
    defer conn.close();

    var check_sum: i64 = 0;
    var i: i64 = 1;
    while (i <= rows) : (i += 1) check_sum += editRequest(&conn, @mod(i - 1, 100) + 1);
    return check_sum;
}

fn adminItemUpdateRequests(rows: i64) i64 {
    var conn = Connection.open();
    conn.prepareAll();
    defer conn.close();

    var check_sum: i64 = 0;
    var i: i64 = 1;
    while (i <= rows) : (i += 1) check_sum += updateRequest(&conn, .begin, i, @mod(i - 1, 100) + 1);
    return check_sum;
}

fn monotonicMicros() i64 {
    var now: c.struct_timespec = undefined;
    _ = c.clock_gettime(c.CLOCK_MONOTONIC, &now);
    return @as(i64, now.tv_sec) * 1_000_000 + @divTrunc(@as(i64, now.tv_nsec), 1000);
}

fn measure(name: [*:0]const u8, items: i64, work: *const fn (i64) i64, rows: i64) void {
    const start = monotonicMicros();
    const check_sum = work(rows);
    const elapsed = monotonicMicros() - start;
    _ = c.printf("%s,%lld,%lld,%lld,%lld\n", name, @as(c_longlong, items), @as(c_longlong, elapsed), @as(c_longlong, @divTrunc(elapsed, items)), @as(c_longlong, check_sum));
}

// Concurrent mode: W workers, each with its own connection and statements, run
// one workload for a fixed time. Every worker opens and prepares before the
// clock starts, warms up, then records the latency of each request that starts
// inside the measured window. Writes use BEGIN IMMEDIATE: a deferred
// transaction that reads and then writes fails at once with SQLITE_BUSY if
// another worker committed in between, without waiting on busy_timeout.

const Workload = enum { read, write, mixed };

const Worker = struct {
    workload: Workload,
    index: i64,
    latencies: [*]i64 = undefined,
    count: usize = 0,
    capacity: usize = 0,

    fn record(self: *Worker, latency: i64) void {
        if (self.count == self.capacity) {
            self.capacity = if (self.capacity == 0) 65536 else self.capacity * 2;
            const grown = c.realloc(if (self.capacity == 65536) null else @ptrCast(self.latencies), self.capacity * @sizeOf(i64)) orelse fail(null, "realloc");
            self.latencies = @ptrCast(@alignCast(grown));
        }
        self.latencies[self.count] = latency;
        self.count += 1;
    }
};

var workers_ready = std.atomic.Value(usize).init(0);
var workers_go = std.atomic.Value(bool).init(false);
var warm_until: i64 = 0;
var measure_until: i64 = 0;

fn runWorker(worker: *Worker) void {
    var conn = Connection.open();
    conn.prepareAll();
    defer conn.close();

    _ = workers_ready.fetchAdd(1, .acq_rel);
    while (!workers_go.load(.acquire)) {}

    // Offset each worker's event ids so workers don't all hit the same rows.
    var sequence: i64 = worker.index * 37;
    while (true) {
        const start = monotonicMicros();
        if (start >= measure_until) break;
        sequence += 1;
        const event_id = @mod(sequence - 1, 100) + 1;
        const write = switch (worker.workload) {
            .read => false,
            .write => true,
            .mixed => @mod(sequence, 10) == 0,
        };
        if (write) {
            _ = updateRequest(&conn, .begin_immediate, sequence, event_id);
        } else {
            _ = editRequest(&conn, event_id);
        }
        if (start >= warm_until) worker.record(monotonicMicros() - start);
    }
}

fn runConcurrent(workload: Workload, count: usize, duration: f64, warmup: f64) void {
    var threads: [256]std.Thread = undefined;
    var state: [256]Worker = undefined;
    if (count > threads.len) fail(null, "too many workers");

    workers_ready.store(0, .release);
    workers_go.store(false, .release);
    for (0..count) |i| {
        state[i] = .{ .workload = workload, .index = @intCast(i) };
        threads[i] = std.Thread.spawn(.{}, runWorker, .{&state[i]}) catch fail(null, "thread");
    }
    while (workers_ready.load(.acquire) < count) {}
    warm_until = monotonicMicros() + @as(i64, @intFromFloat(warmup * 1e6));
    measure_until = warm_until + @as(i64, @intFromFloat(duration * 1e6));
    workers_go.store(true, .release);

    var total: usize = 0;
    for (0..count) |i| {
        threads[i].join();
        total += state[i].count;
    }
    const all_raw = c.malloc(@max(total, 1) * @sizeOf(i64)) orelse fail(null, "malloc");
    const all: [*]i64 = @ptrCast(@alignCast(all_raw));
    var offset: usize = 0;
    for (0..count) |i| {
        @memcpy(all[offset .. offset + state[i].count], state[i].latencies[0..state[i].count]);
        offset += state[i].count;
        if (state[i].capacity != 0) c.free(@ptrCast(state[i].latencies));
    }
    const sorted = all[0..total];
    std.mem.sort(i64, sorted, {}, std.sort.asc(i64));
    const percentile = struct {
        fn at(values: []const i64, p: f64) i64 {
            if (values.len == 0) return 0;
            return values[@intFromFloat(@as(f64, @floatFromInt(values.len - 1)) * p)];
        }
    }.at;
    const max: i64 = if (total == 0) 0 else sorted[total - 1];
    // Any failed query stops this runner, so a printed row always has 0 errors.
    _ = c.printf("zig_sqlite/concurrent/%s,%d,%g,%zu,%.0f,%lld,%lld,%lld,%lld,0\n", @tagName(workload).ptr, @as(c_int, @intCast(count)), duration, total, @as(f64, @floatFromInt(total)) / duration, @as(c_longlong, percentile(sorted, 0.50)), @as(c_longlong, percentile(sorted, 0.95)), @as(c_longlong, percentile(sorted, 0.99)), @as(c_longlong, max));
    _ = c.fflush(null);
    c.free(all_raw);
}

fn removeSqliteFiles() void {
    _ = c.unlink(db_path);
    _ = c.unlink(db_path ++ "-wal");
    _ = c.unlink(db_path ++ "-shm");
}

/// Usage: benchmark concurrent <duration seconds> <warmup seconds> <workers,...>
fn concurrentMain(argc: c_int, argv: [*][*:0]u8) c_int {
    if (argc < 5) {
        _ = c.dprintf(2, "usage: benchmark concurrent <duration> <warmup> <workers,...>\n");
        return 2;
    }
    const duration = c.strtod(argv[2], null);
    const warmup = c.strtod(argv[3], null);
    const workers = std.mem.span(argv[4]);

    removeSqliteFiles();
    _ = seedAppRequestData(0);
    _ = c.printf("case,workers,seconds,requests,requests_per_second,p50_us,p95_us,p99_us,max_us,errors\n");
    for ([_]Workload{ .read, .write, .mixed }) |workload| {
        var tokens = std.mem.tokenizeScalar(u8, workers, ',');
        while (tokens.next()) |token| {
            const count = std.fmt.parseInt(usize, token, 10) catch fail(null, "workers");
            runConcurrent(workload, count, duration, warmup);
        }
    }
    return 0;
}

pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    if (argc > 1 and std.mem.eql(u8, std.mem.span(argv[1]), "concurrent")) return concurrentMain(argc, argv);

    var rows: i64 = if (argc > 1) c.strtoll(argv[1], null, 10) else default_row_count;
    if (rows <= 0) rows = default_row_count;

    removeSqliteFiles();

    _ = c.printf("case,items,micros,us_per_item,check\n");
    measure("zig_sqlite/app_request/seed_dummy_data", 1, seedAppRequestData, rows);
    measure("zig_sqlite/app_request/admin_item_edit", rows, adminItemEditRequests, rows);
    measure("zig_sqlite/app_request/admin_item_update", rows, adminItemUpdateRequests, rows);
    _ = c.fflush(null);
    return 0;
}
