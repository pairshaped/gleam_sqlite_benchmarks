// Go through ncruces/go-sqlite3's direct API, without database/sql and without
// cgo: its SQLite is compiled to Wasm and translated to Go. It was the fastest
// Go SQLite library in this benchmark; go/README.md has the comparison. One
// connection caches a prepared statement per SQL string.
package main

import (
	"errors"
	"fmt"
	"os"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/ncruces/go-sqlite3"
)

const (
	defaultRowCount = 5000
	dbPath          = "go_benchmark.sqlite3"
)

const seedSQL = `
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
`

const casePrefix = "go_ncruces"

type connection struct {
	conn       *sqlite3.Conn
	statements map[string]*sqlite3.Stmt
}

func openConnection() *connection {
	c, err := sqlite3.Open(dbPath)
	must(err)
	// Set the busy timeout before anything that takes a lock, so connections
	// opened at the same moment wait for each other instead of failing.
	must(c.BusyTimeout(5 * time.Second))
	for _, pragma := range []string{
		"pragma journal_mode = WAL",
		"pragma synchronous = NORMAL",
		"pragma foreign_keys = ON",
	} {
		must(c.Exec(pragma))
	}
	return &connection{conn: c, statements: map[string]*sqlite3.Stmt{}}
}

func (c *connection) close() {
	for _, statement := range c.statements {
		must(statement.Close())
	}
	must(c.conn.Close())
}

func (c *connection) statement(query string, args []any) *sqlite3.Stmt {
	statement, ok := c.statements[query]
	if !ok {
		var err error
		statement, _, err = c.conn.Prepare(query)
		must(err)
		c.statements[query] = statement
	}
	for i, arg := range args {
		switch value := arg.(type) {
		case int:
			must(statement.BindInt64(i+1, int64(value)))
		case int64:
			must(statement.BindInt64(i+1, value))
		case string:
			must(statement.BindText(i+1, value))
		default:
			must(fmt.Errorf("unsupported argument %T", arg))
		}
	}
	return statement
}

// one runs a query that returns a single integer.
func (c *connection) one(query string, args ...any) int64 {
	statement := c.statement(query, args)
	if !statement.Step() {
		must(statement.Err())
		must(fmt.Errorf("no row for %q", query))
	}
	value := statement.ColumnInt64(0)
	must(statement.Reset())
	return value
}

// exec runs a statement that returns no rows.
func (c *connection) exec(query string, args ...any) {
	must(c.statement(query, args).Exec())
}

func seedAppRequestData() int64 {
	c := openConnection()
	defer c.close()
	must(c.conn.Exec(seedSQL))
	return 100
}

func adminItemEditRequests(rows int64) int64 {
	c := openConnection()
	defer c.close()

	var check int64
	for i := int64(1); i <= rows; i++ {
		eventID := ((i - 1) % 100) + 1
		check += adminItemEditRequest(c, eventID)
	}
	return check
}

func adminItemEditRequest(c *connection, eventID int64) int64 {
	var check int64
	check += c.one("select id from app_users where id = ?", 1)
	check += c.one("select id from app_clubs where subdomain = ?", "demo")
	check += c.one("select id from app_events where club_id = ? and id = ?", 418, eventID)
	check += c.one("select count(*) from app_sponsors where club_id = ?", 418)
	check += c.one("select count(*) from app_tags where club_id = ?", 418)
	check += c.one("select count(*) from app_taxes where province = ?", "ON")
	check += c.one(`with recursive parents(id, parent_id) as (
            select id, parent_id from app_clubs where id = ?
            union all
            select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
        ) select coalesce(sum(id), 0) from parents`, 418)
	check += c.one("select count(*) from app_fees where club_id in (?, ?, ?) and active = ?", 418, 411, 403, 1)
	check += c.one("select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)", 418, 1, "addon", "both")
	check += c.one("select count(*) from app_addons where addonable_id = ? and addonable_type = ?", eventID, "Event")
	check += c.one("select id from app_fees where id = ?", 1)
	check += c.one("select id from app_clubs where id = ?", 403)
	check += c.one("select id from app_clubs where id = ?", 418)
	check += c.one("select id from app_products where id = ?", 1)
	check += c.one("select id from app_fees where id = ?", 2)
	check += c.one("select count(*) from app_custom_fields where club_id = ?", 418)
	check += c.one("select count(*) from app_event_custom_fields where event_id = ?", eventID)
	check += c.one("select count(*) from app_custom_fields where club_id = ?", 418)
	check += c.one("select count(*) from app_discounts where club_id = ? and active = ?", 418, 1)
	check += c.one("select count(*) from app_discount_items where item_id = ? and item_type = ?", eventID, "Event")
	check += c.one("select count(*) from app_discounts where club_id = ? and active = ?", 418, 1)
	check += c.one("select id from app_branding_palettes where id = ?", 1)
	check += c.one("select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)", "Canada", "club")
	check += c.one("select count(*) from app_config_problems where club_id = ? and ignored = ?", 418, 0)
	check += c.one("select count(*) from app_events where club_id = ?", 418)
	check += c.one("select counter from app_events where id = ?", eventID)
	return check
}

func adminItemUpdateRequests(rows int64) int64 {
	c := openConnection()
	defer c.close()

	var check int64
	for i := int64(1); i <= rows; i++ {
		value, ok := adminItemUpdateRequest(c, "begin", i, ((i-1)%100)+1)
		if !ok {
			must(errors.New("begin: database is locked"))
		}
		check += value
	}
	return check
}

// begin is "begin" for the sequential case and "begin immediate" when several
// workers write at once (see runConcurrent). It returns false when the busy
// timeout expired before the write lock was free, which only BEGIN IMMEDIATE
// can do; any other failure stops the runner.
func adminItemUpdateRequest(c *connection, begin string, sequence, eventID int64) (int64, bool) {
	var check int64
	if err := c.statement(begin, nil).Exec(); err != nil {
		if errors.Is(err, sqlite3.BUSY) {
			return 0, false
		}
		must(err)
	}
	check += c.one("select id from app_users where id = ?", 1)
	check += c.one("select id from app_clubs where subdomain = ?", "demo")
	check += c.one("select id from app_events where club_id = ? and id = ?", 418, eventID)
	check += c.one("select count(*) from app_addons where addonable_id = ? and addonable_type = ?", eventID, "Event")
	check += c.one("select count(*) from app_discount_items where item_id = ? and item_type = ?", eventID, "Event")
	check += c.one("select count(*) from app_tags where club_id = ?", 418)
	c.exec("update app_events set counter = counter + 1, name = ? where id = ?", "Updated Event "+strconv.FormatInt(sequence, 10), eventID)
	c.exec("commit")
	return check + eventID, true
}

func measure(name string, items int64, work func() int64) {
	start := time.Now()
	check := work()
	elapsed := time.Since(start).Microseconds()
	fmt.Printf("%s,%d,%d,%d,%d\n", name, items, elapsed, elapsed/items, check)
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// Concurrent mode: W workers, each a goroutine with its own connection and
// statement cache, run one workload for a fixed time. Every worker opens its
// connection before the clock starts, warms up, then records the latency of
// each request that starts inside the measured window. Writes use BEGIN
// IMMEDIATE: a deferred transaction that reads and then writes fails at once
// with SQLITE_BUSY if another worker committed in between, without waiting on
// busy_timeout.

type workload string

const (
	readWorkload  workload = "read"
	writeWorkload workload = "write"
	mixedWorkload workload = "mixed"
)

func runConcurrent(kind workload, workers int, duration, warmup float64) {
	var ready sync.WaitGroup
	var done sync.WaitGroup
	start := make(chan struct{})
	var warmUntil, measureUntil time.Time
	results := make([][]int64, workers)
	failures := make([]int64, workers)

	ready.Add(workers)
	done.Add(workers)
	for index := range workers {
		go func() {
			defer done.Done()
			c := openConnection()
			defer c.close()
			ready.Done()
			<-start

			latencies := make([]int64, 0, 65536)
			// Offset each worker's event ids so workers don't all hit the same rows.
			sequence := int64(index) * 37
			for {
				began := time.Now()
				if !began.Before(measureUntil) {
					break
				}
				sequence++
				eventID := ((sequence - 1) % 100) + 1
				write := kind == writeWorkload || (kind == mixedWorkload && sequence%10 == 0)
				if write {
					if _, ok := adminItemUpdateRequest(c, "begin immediate", sequence, eventID); !ok {
						// Count timeouts during warm-up too, as the Gleam runner does.
						failures[index]++
						continue
					}
				} else {
					adminItemEditRequest(c, eventID)
				}
				if !began.Before(warmUntil) {
					latencies = append(latencies, time.Since(began).Microseconds())
				}
			}
			results[index] = latencies
		}()
	}

	ready.Wait()
	warmUntil = time.Now().Add(time.Duration(warmup * float64(time.Second)))
	measureUntil = warmUntil.Add(time.Duration(duration * float64(time.Second)))
	close(start)
	done.Wait()

	all := slices.Concat(results...)
	slices.Sort(all)
	percentile := func(p float64) int64 {
		if len(all) == 0 {
			return 0
		}
		return all[int(float64(len(all)-1)*p)]
	}
	var maxLatency int64
	if len(all) > 0 {
		maxLatency = all[len(all)-1]
	}
	var errorCount int64
	for _, count := range failures {
		errorCount += count
	}
	// Errors are writes whose busy timeout expired; anything else stops the runner.
	fmt.Printf("%s/concurrent/%s,%d,%g,%d,%.0f,%d,%d,%d,%d,%d\n", casePrefix, kind, workers, duration,
		len(all), float64(len(all))/duration, percentile(0.50), percentile(0.95), percentile(0.99),
		maxLatency, errorCount)
}

// Usage: benchmark concurrent <duration seconds> <warmup seconds> <workers,...>
func concurrentMain(args []string) {
	if len(args) < 5 {
		fmt.Fprintln(os.Stderr, "usage: benchmark concurrent <duration> <warmup> <workers,...>")
		os.Exit(2)
	}
	duration, err := strconv.ParseFloat(args[2], 64)
	must(err)
	warmup, err := strconv.ParseFloat(args[3], 64)
	must(err)

	for _, suffix := range []string{"", "-wal", "-shm"} {
		_ = os.Remove(dbPath + suffix)
	}
	seedAppRequestData()
	fmt.Println("case,workers,seconds,requests,requests_per_second,p50_us,p95_us,p99_us,max_us,errors")
	for _, kind := range []workload{readWorkload, writeWorkload, mixedWorkload} {
		for _, token := range strings.Split(args[4], ",") {
			workers, err := strconv.Atoi(token)
			must(err)
			runConcurrent(kind, workers, duration, warmup)
		}
	}
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "concurrent" {
		concurrentMain(os.Args)
		return
	}

	rows := int64(defaultRowCount)
	if len(os.Args) > 1 {
		if parsed, err := strconv.ParseInt(os.Args[1], 10, 64); err == nil && parsed > 0 {
			rows = parsed
		}
	}
	for _, suffix := range []string{"", "-wal", "-shm"} {
		_ = os.Remove(dbPath + suffix)
	}

	fmt.Println("case,items,micros,us_per_item,check")
	measure(casePrefix+"/app_request/seed_dummy_data", 1, seedAppRequestData)
	measure(casePrefix+"/app_request/admin_item_edit", rows, func() int64 { return adminItemEditRequests(rows) })
	measure(casePrefix+"/app_request/admin_item_update", rows, func() int64 { return adminItemUpdateRequests(rows) })
}
