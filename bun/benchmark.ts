import { Database, type SQLQueryBindings } from "bun:sqlite";
import { rmSync } from "node:fs";

const DEFAULT_ROW_COUNT = 5_000;
const DB_PATH = "bun_benchmark.sqlite3";

// `prepared` compiles a fresh statement for every query, like `rusqlite`'s
// `query_row` and `sqlight`. `cached` uses `db.query`, Bun's idiomatic API,
// which caches compiled statements by SQL text on the connection.
type QueryMode = "prepared" | "cached";

function main() {
  const rows = rowCountFromArgs();
  removeSqliteFiles(DB_PATH);

  console.log("case,items,micros,us_per_item,check");

  for (const [prefix, mode] of [
    ["bun_sqlite", "prepared"],
    ["bun_sqlite_cached", "cached"],
  ] as const) {
    removeSqliteFiles(DB_PATH);
    measure(`${prefix}/app_request/seed_dummy_data`, 1, seedAppRequestData);
    measure(`${prefix}/app_request/admin_item_edit`, rows, () =>
      adminItemEditRequests(rows, mode),
    );
    measure(`${prefix}/app_request/admin_item_update`, rows, () =>
      adminItemUpdateRequests(rows, mode),
    );
  }
}

function rowCountFromArgs(): number {
  const rows = Number.parseInt(process.argv[2] ?? "", 10);
  return Number.isInteger(rows) && rows > 0 ? rows : DEFAULT_ROW_COUNT;
}

function measure(name: string, items: number, work: () => number) {
  const start = process.hrtime.bigint();
  const check = work();
  const elapsed = Number((process.hrtime.bigint() - start) / 1000n);
  const usPerItem = Math.trunc(elapsed / items);
  console.log(`${name},${items},${elapsed},${usPerItem},${check}`);
}

function removeSqliteFiles(path: string) {
  for (const suffix of ["", "-wal", "-shm"]) {
    rmSync(`${path}${suffix}`, { force: true });
  }
}

function openConnection(): Database {
  const db = new Database(DB_PATH, { create: true });
  db.run("PRAGMA journal_mode = WAL");
  db.run("PRAGMA synchronous = NORMAL");
  db.run("PRAGMA busy_timeout = 5000");
  db.run("PRAGMA foreign_keys = ON");
  return db;
}

function oneFn(db: Database, mode: QueryMode) {
  if (mode === "cached") {
    return (sql: string, ...params: SQLQueryBindings[]): number =>
      db.query(sql).values(...params)[0][0] as number;
  }

  return (sql: string, ...params: SQLQueryBindings[]): number => {
    const statement = db.prepare(sql);
    try {
      return statement.values(...params)[0][0] as number;
    } finally {
      statement.finalize();
    }
  };
}

function seedAppRequestData(): number {
  const db = openConnection();
  try {
    db.run(`
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
    `);
  } finally {
    db.close();
  }
  return 100;
}

function adminItemEditRequests(rows: number, mode: QueryMode): number {
  const db = openConnection();
  try {
    const one = oneFn(db, mode);
    let check = 0;
    for (let i = 1; i <= rows; i++) {
      const eventId = ((i - 1) % 100) + 1;
      check += adminItemEditRequest(one, eventId);
    }
    return check;
  } finally {
    db.close();
  }
}

function adminItemEditRequest(
  one: ReturnType<typeof oneFn>,
  eventId: number,
): number {
  let check = 0;
  check += one("select id from app_users where id = ?", 1);
  check += one("select id from app_clubs where subdomain = ?", "demo");
  check += one(
    "select id from app_events where club_id = ? and id = ?",
    418,
    eventId,
  );
  check += one("select count(*) from app_sponsors where club_id = ?", 418);
  check += one("select count(*) from app_tags where club_id = ?", 418);
  check += one("select count(*) from app_taxes where province = ?", "ON");
  check += one(
    `with recursive parents(id, parent_id) as (
        select id, parent_id from app_clubs where id = ?
        union all
        select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
    ) select coalesce(sum(id), 0) from parents`,
    418,
  );
  check += one(
    "select count(*) from app_fees where club_id in (?, ?, ?) and active = ?",
    418,
    411,
    403,
    1,
  );
  check += one(
    "select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)",
    418,
    1,
    "addon",
    "both",
  );
  check += one(
    "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
    eventId,
    "Event",
  );

  for (const [sql, id] of [
    ["select id from app_fees where id = ?", 1],
    ["select id from app_clubs where id = ?", 403],
    ["select id from app_clubs where id = ?", 418],
    ["select id from app_products where id = ?", 1],
    ["select id from app_fees where id = ?", 2],
  ] as const) {
    check += one(sql, id);
  }

  check += one("select count(*) from app_custom_fields where club_id = ?", 418);
  check += one(
    "select count(*) from app_event_custom_fields where event_id = ?",
    eventId,
  );
  check += one("select count(*) from app_custom_fields where club_id = ?", 418);
  check += one(
    "select count(*) from app_discounts where club_id = ? and active = ?",
    418,
    1,
  );
  check += one(
    "select count(*) from app_discount_items where item_id = ? and item_type = ?",
    eventId,
    "Event",
  );
  check += one(
    "select count(*) from app_discounts where club_id = ? and active = ?",
    418,
    1,
  );
  check += one("select id from app_branding_palettes where id = ?", 1);
  check += one(
    "select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)",
    "Canada",
    "club",
  );
  check += one(
    "select count(*) from app_config_problems where club_id = ? and ignored = ?",
    418,
    0,
  );
  check += one("select count(*) from app_events where club_id = ?", 418);
  check += one("select counter from app_events where id = ?", eventId);
  return check;
}

function adminItemUpdateRequests(rows: number, mode: QueryMode): number {
  const db = openConnection();
  try {
    const one = oneFn(db, mode);
    const run =
      mode === "cached"
        ? (sql: string, ...params: SQLQueryBindings[]) => {
            db.query(sql).run(...params);
          }
        : (sql: string, ...params: SQLQueryBindings[]) => {
            const statement = db.prepare(sql);
            try {
              statement.run(...params);
            } finally {
              statement.finalize();
            }
          };

    const request = db.transaction((sequence: number, eventId: number) => {
      let check = 0;
      check += one("select id from app_users where id = ?", 1);
      check += one("select id from app_clubs where subdomain = ?", "demo");
      check += one(
        "select id from app_events where club_id = ? and id = ?",
        418,
        eventId,
      );
      check += one(
        "select count(*) from app_addons where addonable_id = ? and addonable_type = ?",
        eventId,
        "Event",
      );
      check += one(
        "select count(*) from app_discount_items where item_id = ? and item_type = ?",
        eventId,
        "Event",
      );
      check += one("select count(*) from app_tags where club_id = ?", 418);
      run(
        "update app_events set counter = counter + 1, name = ? where id = ?",
        `Updated Event ${sequence}`,
        eventId,
      );
      return check + eventId;
    });

    let check = 0;
    for (let i = 1; i <= rows; i++) {
      const eventId = ((i - 1) % 100) + 1;
      check += request(i, eventId);
    }
    return check;
  } finally {
    db.close();
  }
}

main();
