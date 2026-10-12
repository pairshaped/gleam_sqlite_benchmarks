// The SQLite C API with no wrapper: the floor every other runner sits on.
// Each connection prepares its statements once and reuses them, so this
// matches the other runners' statement caches without any cache lookup.

#include <pthread.h>
#include <sqlite3.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define DEFAULT_ROW_COUNT 5000
#define DB_PATH "c_benchmark.sqlite3"

static const char *SEED_SQL =
    "drop table if exists app_users;"
    "drop table if exists app_clubs;"
    "drop table if exists app_events;"
    "drop table if exists app_sponsors;"
    "drop table if exists app_tags;"
    "drop table if exists app_taxes;"
    "drop table if exists app_fees;"
    "drop table if exists app_products;"
    "drop table if exists app_addons;"
    "drop table if exists app_custom_fields;"
    "drop table if exists app_event_custom_fields;"
    "drop table if exists app_discounts;"
    "drop table if exists app_discount_items;"
    "drop table if exists app_branding_palettes;"
    "drop table if exists app_admin_alerts;"
    "drop table if exists app_config_problems;"
    "create table app_users (id integer primary key, name text not null);"
    "create table app_clubs (id integer primary key, parent_id integer, subdomain text not null, province text not null);"
    "create index app_clubs_subdomain on app_clubs(subdomain);"
    "create index app_clubs_parent_id on app_clubs(parent_id);"
    "create table app_events (id integer primary key, club_id integer not null, name text not null, counter integer not null);"
    "create index app_events_club_id on app_events(club_id);"
    "create table app_sponsors (id integer primary key, club_id integer not null, name text not null);"
    "create index app_sponsors_club_id on app_sponsors(club_id);"
    "create table app_tags (id integer primary key, club_id integer not null, name text not null);"
    "create index app_tags_club_id on app_tags(club_id);"
    "create table app_taxes (id integer primary key, province text not null, name text not null);"
    "create index app_taxes_province on app_taxes(province);"
    "create table app_fees (id integer primary key, club_id integer not null, name text not null, active integer not null);"
    "create index app_fees_club_id on app_fees(club_id, active);"
    "create table app_products (id integer primary key, club_id integer not null, active integer not null, product_type text not null, name text not null);"
    "create index app_products_club_type on app_products(club_id, active, product_type);"
    "create table app_addons (id integer primary key, addonable_id integer not null, addonable_type text not null, addable_kind text not null, addable_id integer not null, position integer not null);"
    "create index app_addons_addonable on app_addons(addonable_id, addonable_type);"
    "create table app_custom_fields (id integer primary key, club_id integer not null, position integer not null);"
    "create index app_custom_fields_club_id on app_custom_fields(club_id);"
    "create table app_event_custom_fields (id integer primary key, event_id integer not null, position integer not null);"
    "create index app_event_custom_fields_event_id on app_event_custom_fields(event_id);"
    "create table app_discounts (id integer primary key, club_id integer not null, active integer not null);"
    "create index app_discounts_club_id on app_discounts(club_id, active);"
    "create table app_discount_items (id integer primary key, item_id integer not null, item_type text not null, discount_id integer not null);"
    "create index app_discount_items_item on app_discount_items(item_id, item_type);"
    "create table app_branding_palettes (id integer primary key, slug text not null);"
    "create table app_admin_alerts (id integer primary key, country text, club_type text);"
    "create table app_config_problems (id integer primary key, club_id integer not null, ignored integer not null);"
    "create index app_config_problems_club_id on app_config_problems(club_id, ignored);"
    "insert into app_users (id, name) values (1, 'Admin');"
    "insert into app_clubs (id, parent_id, subdomain, province) values"
    " (403, null, 'canada', 'ON'), (411, 403, 'ontario', 'ON'), (418, 411, 'demo', 'ON');"
    "insert into app_branding_palettes (id, slug) values (1, 'default');"
    "insert into app_admin_alerts (id, country, club_type) values (330, 'Canada', 'club');"
    "insert into app_config_problems (id, club_id, ignored) values (1, 418, 0);"
    "insert into app_taxes (id, province, name) values (1, 'ON', 'HST'), (2, 'ON', 'GST');"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 100)"
    " insert into app_events (id, club_id, name, counter) select id, 418, 'Event ' || id, 0 from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 20)"
    " insert into app_sponsors (id, club_id, name) select id, 418, 'Sponsor ' || id from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 30)"
    " insert into app_tags (id, club_id, name) select id, 418, 'Tag ' || id from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 12)"
    " insert into app_fees (id, club_id, name, active)"
    " select id, case id % 3 when 0 then 403 when 1 then 411 else 418 end, 'Fee ' || id, 1 from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 15)"
    " insert into app_products (id, club_id, active, product_type, name)"
    " select id, 418, 1, case when id % 2 = 0 then 'addon' else 'both' end, 'Product ' || id from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 300)"
    " insert into app_addons (id, addonable_id, addonable_type, addable_kind, addable_id, position)"
    " select id, ((id - 1) % 100) + 1, 'Event', case when id % 2 = 0 then 'Product' else 'Fee' end, ((id - 1) % 12) + 1, id % 3 from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 10)"
    " insert into app_custom_fields (id, club_id, position) select id, 418, id from seed;"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)"
    " insert into app_event_custom_fields (id, event_id, position) select id, ((id - 1) % 100) + 1, id % 5 from seed;"
    "insert into app_discounts (id, club_id, active) values (1, 418, 1), (2, 418, 1), (3, 418, 0);"
    "with recursive seed(id) as (values(1) union all select id + 1 from seed where id < 200)"
    " insert into app_discount_items (id, item_id, item_type, discount_id)"
    " select id, ((id - 1) % 100) + 1, 'Event', ((id - 1) % 2) + 1 from seed;";

// The 22 distinct statements the edit and update requests use.
enum {
    S_USER,
    S_CLUB_BY_SUBDOMAIN,
    S_EVENT,
    S_SPONSORS,
    S_TAGS,
    S_TAXES,
    S_PARENT_CHAIN,
    S_FEES,
    S_PRODUCTS,
    S_ADDONS,
    S_FEE_ID,
    S_CLUB_ID,
    S_PRODUCT_ID,
    S_CUSTOM_FIELDS,
    S_EVENT_CUSTOM_FIELDS,
    S_DISCOUNTS,
    S_DISCOUNT_ITEMS,
    S_BRANDING_PALETTE,
    S_ADMIN_ALERTS,
    S_CONFIG_PROBLEMS,
    S_EVENTS,
    S_EVENT_COUNTER,
    S_UPDATE_EVENT,
    S_BEGIN,
    S_BEGIN_IMMEDIATE,
    S_COMMIT,
    STATEMENT_COUNT
};

static const char *STATEMENT_SQL[STATEMENT_COUNT] = {
    [S_USER] = "select id from app_users where id = ?",
    [S_CLUB_BY_SUBDOMAIN] = "select id from app_clubs where subdomain = ?",
    [S_EVENT] = "select id from app_events where club_id = ? and id = ?",
    [S_SPONSORS] = "select count(*) from app_sponsors where club_id = ?",
    [S_TAGS] = "select count(*) from app_tags where club_id = ?",
    [S_TAXES] = "select count(*) from app_taxes where province = ?",
    [S_PARENT_CHAIN] =
        ("with recursive parents(id, parent_id) as ("
        " select id, parent_id from app_clubs where id = ?"
        " union all"
        " select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id"
        ") select coalesce(sum(id), 0) from parents"),
    [S_FEES] = "select count(*) from app_fees where club_id in (?, ?, ?) and active = ?",
    [S_PRODUCTS] =
        "select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)",
    [S_ADDONS] = "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
    [S_FEE_ID] = "select id from app_fees where id = ?",
    [S_CLUB_ID] = "select id from app_clubs where id = ?",
    [S_PRODUCT_ID] = "select id from app_products where id = ?",
    [S_CUSTOM_FIELDS] = "select count(*) from app_custom_fields where club_id = ?",
    [S_EVENT_CUSTOM_FIELDS] = "select count(*) from app_event_custom_fields where event_id = ?",
    [S_DISCOUNTS] = "select count(*) from app_discounts where club_id = ? and active = ?",
    [S_DISCOUNT_ITEMS] =
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
    [S_BRANDING_PALETTE] = "select id from app_branding_palettes where id = ?",
    [S_ADMIN_ALERTS] =
        ("select count(*) from app_admin_alerts where (country = ? or country is null)"
        " and (club_type = ? or club_type is null)"),
    [S_CONFIG_PROBLEMS] =
        "select count(*) from app_config_problems where club_id = ? and ignored = ?",
    [S_EVENTS] = "select count(*) from app_events where club_id = ?",
    [S_EVENT_COUNTER] = "select counter from app_events where id = ?",
    [S_UPDATE_EVENT] = "update app_events set counter = counter + 1, name = ? where id = ?",
    [S_BEGIN] = "begin",
    [S_BEGIN_IMMEDIATE] = "begin immediate",
    [S_COMMIT] = "commit",
};

// A bound parameter: an integer, text, or the request's event id.
typedef enum { P_INT, P_TEXT, P_EVENT_ID } ParamKind;

typedef struct {
    ParamKind kind;
    sqlite3_int64 value;
    const char *text;
} Param;

typedef struct {
    int statement;
    int param_count;
    Param params[4];
} Query;

#define I(v) {P_INT, (v), NULL}
#define T(v) {P_TEXT, 0, (v)}
#define E {P_EVENT_ID, 0, NULL}

static const Query EDIT_QUERIES[] = {
    {S_USER, 1, {I(1)}},
    {S_CLUB_BY_SUBDOMAIN, 1, {T("demo")}},
    {S_EVENT, 2, {I(418), E}},
    {S_SPONSORS, 1, {I(418)}},
    {S_TAGS, 1, {I(418)}},
    {S_TAXES, 1, {T("ON")}},
    {S_PARENT_CHAIN, 1, {I(418)}},
    {S_FEES, 4, {I(418), I(411), I(403), I(1)}},
    {S_PRODUCTS, 4, {I(418), I(1), T("addon"), T("both")}},
    {S_ADDONS, 2, {E, T("Event")}},
    {S_FEE_ID, 1, {I(1)}},
    {S_CLUB_ID, 1, {I(403)}},
    {S_CLUB_ID, 1, {I(418)}},
    {S_PRODUCT_ID, 1, {I(1)}},
    {S_FEE_ID, 1, {I(2)}},
    {S_CUSTOM_FIELDS, 1, {I(418)}},
    {S_EVENT_CUSTOM_FIELDS, 1, {E}},
    {S_CUSTOM_FIELDS, 1, {I(418)}},
    {S_DISCOUNTS, 2, {I(418), I(1)}},
    {S_DISCOUNT_ITEMS, 2, {E, T("Event")}},
    {S_DISCOUNTS, 2, {I(418), I(1)}},
    {S_BRANDING_PALETTE, 1, {I(1)}},
    {S_ADMIN_ALERTS, 2, {T("Canada"), T("club")}},
    {S_CONFIG_PROBLEMS, 2, {I(418), I(0)}},
    {S_EVENTS, 1, {I(418)}},
    {S_EVENT_COUNTER, 1, {E}},
};

static const Query UPDATE_QUERIES[] = {
    {S_USER, 1, {I(1)}},
    {S_CLUB_BY_SUBDOMAIN, 1, {T("demo")}},
    {S_EVENT, 2, {I(418), E}},
    {S_ADDONS, 2, {E, T("Event")}},
    {S_DISCOUNT_ITEMS, 2, {E, T("Event")}},
    {S_TAGS, 1, {I(418)}},
};

#define LENGTH(array) (sizeof(array) / sizeof((array)[0]))

static void die(sqlite3 *db, const char *what) {
    fprintf(stderr, "%s failed: %s\n", what, db ? sqlite3_errmsg(db) : "unknown error");
    exit(1);
}

static void check_rc(sqlite3 *db, int rc, const char *what) {
    if (rc != SQLITE_OK) die(db, what);
}

static sqlite3 *open_connection(void) {
    sqlite3 *db = NULL;
    check_rc(db, sqlite3_open(DB_PATH, &db), "open");
    // Set the busy timeout before anything that takes a lock, so connections
    // opened at the same moment wait for each other instead of failing.
    check_rc(db, sqlite3_busy_timeout(db, 5000), "busy_timeout");
    check_rc(db,
             sqlite3_exec(db,
                          "pragma journal_mode = WAL;"
                          "pragma synchronous = NORMAL;"
                          "pragma foreign_keys = ON;",
                          NULL, NULL, NULL),
             "pragmas");
    return db;
}

static void prepare_all(sqlite3 *db, sqlite3_stmt *statements[STATEMENT_COUNT]) {
    for (int i = 0; i < STATEMENT_COUNT; i++) {
        check_rc(db, sqlite3_prepare_v3(db, STATEMENT_SQL[i], -1, SQLITE_PREPARE_PERSISTENT,
                                        &statements[i], NULL),
                 STATEMENT_SQL[i]);
    }
}

static void finalize_all(sqlite3_stmt *statements[STATEMENT_COUNT]) {
    for (int i = 0; i < STATEMENT_COUNT; i++) sqlite3_finalize(statements[i]);
}

static void bind_params(sqlite3 *db, sqlite3_stmt *statement, const Query *query,
                        sqlite3_int64 event_id) {
    for (int i = 0; i < query->param_count; i++) {
        const Param *param = &query->params[i];
        int rc;
        switch (param->kind) {
        case P_INT:
            rc = sqlite3_bind_int64(statement, i + 1, param->value);
            break;
        case P_TEXT:
            rc = sqlite3_bind_text(statement, i + 1, param->text, -1, SQLITE_STATIC);
            break;
        case P_EVENT_ID:
        default:
            rc = sqlite3_bind_int64(statement, i + 1, event_id);
            break;
        }
        check_rc(db, rc, "bind");
    }
}

static sqlite3_int64 one(sqlite3 *db, sqlite3_stmt *statements[], const Query *query,
                         sqlite3_int64 event_id) {
    sqlite3_stmt *statement = statements[query->statement];
    bind_params(db, statement, query, event_id);
    if (sqlite3_step(statement) != SQLITE_ROW) die(db, STATEMENT_SQL[query->statement]);
    sqlite3_int64 value = sqlite3_column_int64(statement, 0);
    sqlite3_reset(statement);
    return value;
}

static void run(sqlite3 *db, sqlite3_stmt *statement) {
    if (sqlite3_step(statement) != SQLITE_DONE) die(db, sqlite3_sql(statement));
    sqlite3_reset(statement);
}

static sqlite3_int64 seed_app_request_data(sqlite3_int64 rows) {
    (void)rows;
    sqlite3 *db = open_connection();
    check_rc(db, sqlite3_exec(db, SEED_SQL, NULL, NULL, NULL), "seed");
    sqlite3_close(db);
    return 100;
}

static sqlite3_int64 edit_request(sqlite3 *db, sqlite3_stmt *statements[],
                                  sqlite3_int64 event_id) {
    sqlite3_int64 check = 0;
    for (size_t q = 0; q < LENGTH(EDIT_QUERIES); q++) {
        check += one(db, statements, &EDIT_QUERIES[q], event_id);
    }
    return check;
}

// `begin` is S_BEGIN for the sequential cases and S_BEGIN_IMMEDIATE when
// several workers write at once (see run_concurrent).
static sqlite3_int64 update_request(sqlite3 *db, sqlite3_stmt *statements[], int begin,
                                    sqlite3_int64 sequence, sqlite3_int64 event_id) {
    char name[64];
    sqlite3_int64 check = 0;
    run(db, statements[begin]);
    for (size_t q = 0; q < LENGTH(UPDATE_QUERIES); q++) {
        check += one(db, statements, &UPDATE_QUERIES[q], event_id);
    }
    snprintf(name, sizeof(name), "Updated Event %lld", (long long)sequence);
    sqlite3_stmt *update = statements[S_UPDATE_EVENT];
    // The buffer outlives the step that reads it, so SQLite needn't copy it.
    check_rc(db, sqlite3_bind_text(update, 1, name, -1, SQLITE_STATIC), "bind");
    check_rc(db, sqlite3_bind_int64(update, 2, event_id), "bind");
    run(db, update);
    run(db, statements[S_COMMIT]);
    return check + event_id;
}

static sqlite3_int64 admin_item_edit_requests(sqlite3_int64 rows) {
    sqlite3 *db = open_connection();
    sqlite3_stmt *statements[STATEMENT_COUNT];
    prepare_all(db, statements);

    sqlite3_int64 check = 0;
    for (sqlite3_int64 i = 1; i <= rows; i++) {
        check += edit_request(db, statements, ((i - 1) % 100) + 1);
    }

    finalize_all(statements);
    sqlite3_close(db);
    return check;
}

static sqlite3_int64 admin_item_update_requests(sqlite3_int64 rows) {
    sqlite3 *db = open_connection();
    sqlite3_stmt *statements[STATEMENT_COUNT];
    prepare_all(db, statements);

    sqlite3_int64 check = 0;
    for (sqlite3_int64 i = 1; i <= rows; i++) {
        check += update_request(db, statements, S_BEGIN, i, ((i - 1) % 100) + 1);
    }

    finalize_all(statements);
    sqlite3_close(db);
    return check;
}

static long long monotonic_micros(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (long long)now.tv_sec * 1000000LL + now.tv_nsec / 1000;
}

static void measure(const char *name, sqlite3_int64 items,
                    sqlite3_int64 (*work)(sqlite3_int64), sqlite3_int64 rows) {
    long long start = monotonic_micros();
    sqlite3_int64 check = work(rows);
    long long elapsed = monotonic_micros() - start;
    printf("%s,%lld,%lld,%lld,%lld\n", name, (long long)items, elapsed,
           elapsed / (long long)items, (long long)check);
}

static void remove_sqlite_files(void) {
    unlink(DB_PATH);
    unlink(DB_PATH "-wal");
    unlink(DB_PATH "-shm");
}

// Concurrent mode: W workers, each with its own connection and statements, run
// one workload for a fixed time. Every worker opens and prepares before the
// clock starts, warms up, then records the latency of each request that starts
// inside the measured window. Writes use BEGIN IMMEDIATE: a deferred
// transaction that reads and then writes fails at once with SQLITE_BUSY if
// another worker committed in between, without waiting on busy_timeout.

typedef enum { W_READ, W_WRITE, W_MIXED } Workload;

static const char *WORKLOAD_NAMES[] = {"read", "write", "mixed"};

typedef struct {
    Workload workload;
    int index;
    long long *latencies;
    size_t count;
    size_t capacity;
} Worker;

static atomic_int workers_ready;
static atomic_int workers_go;
static long long warm_until;
static long long measure_until;

static void record(Worker *worker, long long latency) {
    if (worker->count == worker->capacity) {
        worker->capacity = worker->capacity ? worker->capacity * 2 : 65536;
        worker->latencies = realloc(worker->latencies, worker->capacity * sizeof(long long));
        if (!worker->latencies) die(NULL, "realloc");
    }
    worker->latencies[worker->count++] = latency;
}

static void *run_worker(void *argument) {
    Worker *worker = argument;
    sqlite3 *db = open_connection();
    sqlite3_stmt *statements[STATEMENT_COUNT];
    prepare_all(db, statements);

    atomic_fetch_add(&workers_ready, 1);
    while (!atomic_load_explicit(&workers_go, memory_order_acquire)) {
    }

    // Offset each worker's event ids so workers don't all hit the same rows.
    sqlite3_int64 sequence = (sqlite3_int64)worker->index * 37;
    for (;;) {
        long long start = monotonic_micros();
        if (start >= measure_until) break;
        sequence++;
        sqlite3_int64 event_id = ((sequence - 1) % 100) + 1;
        int write = worker->workload == W_WRITE ||
                    (worker->workload == W_MIXED && sequence % 10 == 0);
        if (write) {
            update_request(db, statements, S_BEGIN_IMMEDIATE, sequence, event_id);
        } else {
            edit_request(db, statements, event_id);
        }
        if (start >= warm_until) record(worker, monotonic_micros() - start);
    }

    finalize_all(statements);
    sqlite3_close(db);
    return NULL;
}

static int compare_long_long(const void *a, const void *b) {
    long long left = *(const long long *)a;
    long long right = *(const long long *)b;
    return (left > right) - (left < right);
}

static void run_concurrent(Workload workload, int workers, double duration, double warmup) {
    pthread_t threads[workers];
    Worker state[workers];
    atomic_store(&workers_ready, 0);
    atomic_store(&workers_go, 0);
    for (int i = 0; i < workers; i++) {
        state[i] = (Worker){.workload = workload, .index = i};
        if (pthread_create(&threads[i], NULL, run_worker, &state[i]) != 0) die(NULL, "thread");
    }
    while (atomic_load(&workers_ready) < workers) {
    }
    warm_until = monotonic_micros() + (long long)(warmup * 1e6);
    measure_until = warm_until + (long long)(duration * 1e6);
    atomic_store_explicit(&workers_go, 1, memory_order_release);

    size_t total = 0;
    for (int i = 0; i < workers; i++) {
        pthread_join(threads[i], NULL);
        total += state[i].count;
    }
    long long *all = malloc((total ? total : 1) * sizeof(long long));
    if (!all) die(NULL, "malloc");
    size_t offset = 0;
    for (int i = 0; i < workers; i++) {
        memcpy(all + offset, state[i].latencies, state[i].count * sizeof(long long));
        offset += state[i].count;
        free(state[i].latencies);
    }
    qsort(all, total, sizeof(long long), compare_long_long);
    long long p50 = total ? all[(size_t)((total - 1) * 0.50)] : 0;
    long long p95 = total ? all[(size_t)((total - 1) * 0.95)] : 0;
    long long p99 = total ? all[(size_t)((total - 1) * 0.99)] : 0;
    long long max = total ? all[total - 1] : 0;
    free(all);

    // Any failed query stops this runner, so a printed row always has 0 errors.
    printf("c_sqlite/concurrent/%s,%d,%g,%zu,%.0f,%lld,%lld,%lld,%lld,0\n",
           WORKLOAD_NAMES[workload], workers, duration, total, total / duration, p50, p95, p99,
           max);
    fflush(stdout);
}

// Usage: benchmark concurrent <duration seconds> <warmup seconds> <workers,...>
static int concurrent_main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr, "usage: %s concurrent <duration> <warmup> <workers,...>\n", argv[0]);
        return 2;
    }
    double duration = strtod(argv[2], NULL);
    double warmup = strtod(argv[3], NULL);

    remove_sqlite_files();
    seed_app_request_data(0);
    puts("case,workers,seconds,requests,requests_per_second,p50_us,p95_us,p99_us,max_us,errors");
    for (int workload = W_READ; workload <= W_MIXED; workload++) {
        char *list = strdup(argv[4]);
        for (char *token = strtok(list, ","); token; token = strtok(NULL, ",")) {
            run_concurrent((Workload)workload, atoi(token), duration, warmup);
        }
        free(list);
    }
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "concurrent") == 0) return concurrent_main(argc, argv);

    sqlite3_int64 rows = argc > 1 ? strtoll(argv[1], NULL, 10) : DEFAULT_ROW_COUNT;
    if (rows <= 0) rows = DEFAULT_ROW_COUNT;

    remove_sqlite_files();
    puts("case,items,micros,us_per_item,check");
    measure("c_sqlite/app_request/seed_dummy_data", 1, seed_app_request_data, rows);
    measure("c_sqlite/app_request/admin_item_edit", rows, admin_item_edit_requests, rows);
    measure("c_sqlite/app_request/admin_item_update", rows, admin_item_update_requests, rows);
    return 0;
}
