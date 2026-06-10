# frozen_string_literal: true

require "bundler/setup"
require "logger"
require "timeout"
require "active_record"

DEFAULT_ROW_COUNT = 10_000
BENCHMARK_DB_PATH = "ruby_benchmark.sqlite3"
CASE_TIMEOUT_SECONDS = Integer(ENV.fetch("BENCH_CASE_TIMEOUT_SECONDS", "60"))
PROFILE_ROW_COUNT = 300_000
CONCURRENT_PROFILE_WRITER_WORKERS = 4
MAX_PROFILE_UPDATE_ATTEMPTS_PER_WORKER = 1_000
HEAVY_CTE_MULTIPLIER = 100
HEAVY_READ_MULTIPLIER = 64
HEAVY_MODULUS = 2_147_483_647

class BenchmarkRow < ActiveRecord::Base
  self.table_name = "benchmark_rows"
end

class PreparedInsertRow < ActiveRecord::Base
  self.table_name = "prepared_insert_rows"
end

class ProfileRow < ActiveRecord::Base
  self.table_name = "profile_rows"
end

class AppUser < ActiveRecord::Base
  self.table_name = "app_users"
end

class AppClub < ActiveRecord::Base
  self.table_name = "app_clubs"
end

class AppEvent < ActiveRecord::Base
  self.table_name = "app_events"
end

class AppSponsor < ActiveRecord::Base
  self.table_name = "app_sponsors"
end

class AppTag < ActiveRecord::Base
  self.table_name = "app_tags"
end

class AppTax < ActiveRecord::Base
  self.table_name = "app_taxes"
end

class AppFee < ActiveRecord::Base
  self.table_name = "app_fees"
end

class AppProduct < ActiveRecord::Base
  self.table_name = "app_products"
end

class AppAddon < ActiveRecord::Base
  self.table_name = "app_addons"
end

class AppCustomField < ActiveRecord::Base
  self.table_name = "app_custom_fields"
end

class AppEventCustomField < ActiveRecord::Base
  self.table_name = "app_event_custom_fields"
end

class AppDiscount < ActiveRecord::Base
  self.table_name = "app_discounts"
end

class AppDiscountItem < ActiveRecord::Base
  self.table_name = "app_discount_items"
end

class AppBrandingPalette < ActiveRecord::Base
  self.table_name = "app_branding_palettes"
end

class AppAdminAlert < ActiveRecord::Base
  self.table_name = "app_admin_alerts"
end

class AppConfigProblem < ActiveRecord::Base
  self.table_name = "app_config_problems"
end

def main
  $stdout.sync = true

  rows = row_count_from_args
  File.delete(BENCHMARK_DB_PATH) if File.exist?(BENCHMARK_DB_PATH)

  ActiveRecord::Base.logger = nil
  ActiveRecord.verbose_query_logs = false if ActiveRecord.respond_to?(:verbose_query_logs=)
  establish_benchmark_connection

  puts "case,items,micros,us_per_item,check"

  measure("active_record/app_request/seed_dummy_data", 1) do
    seed_app_request_data
  end

  measure("active_record/app_request/admin_item_edit", rows) do
    app_admin_item_edit_requests(rows)
  end

  measure("active_record/app_request/admin_item_update", rows) do
    app_admin_item_update_requests(rows)
  end
ensure
  ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
end

def row_count_from_args
  Integer(ARGV.fetch(0, DEFAULT_ROW_COUNT))
rescue ArgumentError
  DEFAULT_ROW_COUNT
end

def measure(name, items)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
  check = Timeout.timeout(CASE_TIMEOUT_SECONDS) { yield }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start
  print_csv_row(name, items, elapsed, elapsed / items, check)
rescue Timeout::Error
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start
  print_csv_row("#{name}/timeout", items, elapsed, elapsed / items, CASE_TIMEOUT_SECONDS)
end

def measure_with_extra_rows(name, items)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
  check, extra_rows = Timeout.timeout(CASE_TIMEOUT_SECONDS) { yield }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start
  us_per_item = elapsed / items
  print_csv_row(name, items, elapsed, us_per_item, check)
  extra_rows.each do |extra_name, extra_check|
    print_csv_row(extra_name, items, elapsed, us_per_item, extra_check)
  end
rescue Timeout::Error
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start
  print_csv_row("#{name}/timeout", items, elapsed, elapsed / items, CASE_TIMEOUT_SECONDS)
end

def print_csv_row(name, items, micros, us_per_item, check)
  puts "#{name},#{items},#{micros},#{us_per_item},#{check}"
end

def establish_benchmark_connection
  ActiveRecord::Base.establish_connection(
    adapter: "sqlite3",
    database: BENCHMARK_DB_PATH,
    pool: CONCURRENT_PROFILE_WRITER_WORKERS + 2,
    timeout: 5000
  )
end

def configure_app_connection
  connection = ActiveRecord::Base.connection
  connection.execute("PRAGMA journal_mode=WAL")
  connection.execute("PRAGMA busy_timeout=5000")
  connection.execute("PRAGMA foreign_keys=ON")
  verify_app_pragmas(connection)
end

def verify_app_pragmas(connection)
  journal_mode = connection.select_value("PRAGMA journal_mode").to_s
  busy_timeout = connection.select_value("PRAGMA busy_timeout").to_i
  foreign_keys = connection.select_value("PRAGMA foreign_keys").to_i

  raise "expected WAL journal mode, got #{journal_mode.inspect}" unless journal_mode == "wal"
  raise "expected busy_timeout=5000, got #{busy_timeout}" unless busy_timeout == 5000
  raise "expected foreign_keys=1, got #{foreign_keys}" unless foreign_keys == 1
end

def measure_concurrent_profile_updates(name, items, attempts_per_worker)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)
  reader, writer = IO.pipe

  pid = fork do
    reader.close
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
    establish_benchmark_connection
    stats = concurrent_profile_updates(attempts_per_worker)
    writer.write(Marshal.dump(["ok", stats]))
  rescue StandardError => error
    writer.write(Marshal.dump(["error", "#{error.class}: #{error.message}"]))
  ensure
    writer.close
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connected?
    exit!(0)
  end

  writer.close
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + CASE_TIMEOUT_SECONDS
  status = nil

  loop do
    waited_pid = Process.waitpid(pid, Process::WNOHANG)
    if waited_pid
      status = $?
      break
    end

    if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      Process.kill("KILL", pid)
      Process.waitpid(pid)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start
      print_csv_row("#{name}/timeout", items, elapsed, elapsed / items, CASE_TIMEOUT_SECONDS)
      return
    end

    sleep 0.05
  end

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start
  state, payload = Marshal.load(reader.read)
  raise payload unless state == "ok" && status&.success?

  print_csv_row(name, items, elapsed, elapsed / items, payload.fetch(:check))
  print_csv_row(
    "active_record/stress/concurrent_profile_updates/failures",
    items,
    elapsed,
    elapsed / items,
    payload.fetch(:failures)
  )
ensure
  reader&.close unless reader&.closed?
  writer&.close unless writer&.closed?
end

def create_schema
  connection = ActiveRecord::Base.connection
  connection.execute("drop table if exists benchmark_rows")
  connection.execute(<<~SQL)
    create table benchmark_rows (
      id integer primary key,
      payload text not null,
      counter integer not null
    )
  SQL
  connection.execute("drop table if exists prepared_insert_rows")
  connection.execute(<<~SQL)
    create table prepared_insert_rows (
      id integer primary key,
      payload text not null,
      counter integer not null
    )
  SQL
  connection.execute("drop table if exists profile_rows")
  connection.execute(<<~SQL)
    create table profile_rows (
      id integer primary key,
      display_name text not null,
      email text not null,
      bio text not null,
      city text not null,
      country text not null,
      login_count integer not null,
      reputation integer not null,
      feature_flags integer not null,
      updated_at integer not null,
      version integer not null
    )
  SQL
end

def model_insert_tx(rows)
  check = 0
  BenchmarkRow.transaction do
    1.upto(rows) do |i|
      BenchmarkRow.create!(id: i, payload: "payload-#{i}", counter: 0)
      check += i
    end
  end
  check
end

def model_point_select_pk(rows)
  check = 0
  1.upto(rows) do |i|
    check += BenchmarkRow.find(i).id
  end
  check
end

def model_update_tx(rows)
  check = 0
  BenchmarkRow.transaction do
    1.upto(rows) do |i|
      row = BenchmarkRow.find(i)
      row.counter += 1
      row.save!
      check += i
    end
  end
  check
end

def seed_profile_rows
  ActiveRecord::Base.connection.execute(<<~SQL)
    with recursive seed(id) as (
      values(1)
      union all
      select id + 1 from seed where id < #{PROFILE_ROW_COUNT}
    )
    insert into profile_rows (
      id,
      display_name,
      email,
      bio,
      city,
      country,
      login_count,
      reputation,
      feature_flags,
      updated_at,
      version
    )
    select
      id,
      'Display ' || id,
      'profile-' || id || '@example.test',
      'Bio ' || id,
      'City ' || (id % 1000),
      'Country ' || (id % 200),
      id % 100,
      id % 10000,
      id % 1024,
      1700000000 + id,
      1
    from seed
  SQL

  count = ProfileRow.count
  raise "profile seed returned #{count} rows" unless count == PROFILE_ROW_COUNT

  count
end

def seed_app_request_data
  ActiveRecord::Base.connection.raw_connection.execute_batch(<<~SQL)
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
    insert into app_events (id, club_id, name, counter) select id, 418, 'Event ' || id, 0 from seed;
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
  SQL
  reset_app_models
  100
end

def reset_app_models
  [
    AppUser,
    AppClub,
    AppEvent,
    AppSponsor,
    AppTag,
    AppTax,
    AppFee,
    AppProduct,
    AppAddon,
    AppCustomField,
    AppEventCustomField,
    AppDiscount,
    AppDiscountItem,
    AppBrandingPalette,
    AppAdminAlert,
    AppConfigProblem
  ].each(&:reset_column_information)
end

def app_admin_item_edit_requests(rows)
  check = 0
  1.upto(rows) do |i|
    event_id = ((i - 1) % 100) + 1
    check += app_admin_item_edit_request(event_id)
  end
  check
end

def app_admin_item_edit_request(event_id)
  check = 0
  check += AppUser.find(1).id
  check += AppClub.find_by!(subdomain: "demo").id
  check += AppEvent.find_by!(club_id: 418, id: event_id).id
  check += AppSponsor.where(club_id: 418).count
  check += AppTag.where(club_id: 418).count
  check += AppTax.where(province: "ON").count
  check += parent_club_id_sum(418)
  check += AppFee.where(club_id: [418, 411, 403], active: 1).count
  check += AppProduct.where(club_id: 418, active: 1, product_type: ["addon", "both"]).count
  check += AppAddon.where(addonable_id: event_id, addonable_type: "Event").count
  check += AppFee.find(1).id
  check += AppClub.find(403).id
  check += AppClub.find(418).id
  check += AppProduct.find(1).id
  check += AppFee.find(2).id
  check += AppCustomField.where(club_id: 418).count
  check += AppEventCustomField.where(event_id: event_id).count
  check += AppCustomField.where(club_id: 418).count
  check += AppDiscount.where(club_id: 418, active: 1).count
  check += AppDiscountItem.where(item_id: event_id, item_type: "Event").count
  check += AppDiscount.where(club_id: 418, active: 1).count
  check += AppBrandingPalette.find(1).id
  check += AppAdminAlert.where(country: ["Canada", nil], club_type: ["club", nil]).count
  check += AppConfigProblem.where(club_id: 418, ignored: 0).count
  check += AppEvent.where(club_id: 418).count
  check += AppEvent.find(event_id).counter
  check
end

def parent_club_id_sum(club_id)
  check = 0
  club = AppClub.find(club_id)
  loop do
    check += club.id
    break if club.parent_id.nil?

    club = AppClub.find(club.parent_id)
  end
  check
end

def app_admin_item_update_requests(rows)
  check = 0
  1.upto(rows) do |i|
    event_id = ((i - 1) % 100) + 1
    AppEvent.transaction(requires_new: true) do
      check += AppUser.find(1).id
      check += AppClub.find_by!(subdomain: "demo").id
      event = AppEvent.find_by!(club_id: 418, id: event_id)
      check += event.id
      check += AppAddon.where(addonable_id: event_id, addonable_type: "Event").count
      check += AppDiscountItem.where(item_id: event_id, item_type: "Event").count
      check += AppTag.where(club_id: 418).count
      event.counter += 1
      event.name = "Updated Event #{i}"
      event.save!
      check += event_id
    end
  end
  check
end

def profile_model_update_one_tx(rows)
  check = 0
  1.upto(rows) do |i|
    id = ((i - 1) % PROFILE_ROW_COUNT) + 1
    ProfileRow.transaction(requires_new: true) do
      profile = ProfileRow.find(id)
      assign_profile_update(profile, i, id)
      profile.save!
    end
    check += id
  end
  check
end

def concurrent_profile_updates(attempts_per_worker)
  queue = Queue.new
  threads = 1.upto(CONCURRENT_PROFILE_WRITER_WORKERS).map do |worker_id|
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        configure_app_connection
        stats = { check: 0, failures: 0 }
        1.upto(attempts_per_worker) do |attempt|
          sequence = ((worker_id - 1) * attempts_per_worker) + attempt
          id = ((sequence - 1) % PROFILE_ROW_COUNT) + 1
          begin
            ProfileRow.transaction(requires_new: true) do
              profile = ProfileRow.find(id)
              assign_profile_update(profile, sequence, id, worker_id)
              profile.save!
            end
            stats[:check] += sequence + id
          rescue ActiveRecord::StatementInvalid => error
            raise unless expected_lock_error?(error)

            stats[:failures] += 1
          end
        end
        queue << stats
      end
    end
  end

  threads.each(&:value)
  combined = { check: 0, failures: 0 }
  CONCURRENT_PROFILE_WRITER_WORKERS.times do
    stats = queue.pop
    combined[:check] += stats.fetch(:check)
    combined[:failures] += stats.fetch(:failures)
  end
  combined
end

def assign_profile_update(profile, sequence, id, worker_id = nil)
  profile.display_name = worker_id ? "Worker #{worker_id} Profile #{id}" : "Display #{sequence}"
  profile.email = worker_id ? "profile-#{id}-worker-#{worker_id}@example.test" : "profile-#{id}@example.test"
  profile.bio = "Bio #{sequence}"
  profile.city = "City #{sequence % 1000}"
  profile.country = "Country #{sequence % 200}"
  profile.login_count = sequence
  profile.reputation = id + sequence
  profile.feature_flags = sequence % 1024
  profile.updated_at = 1_700_000_000 + sequence
  profile.version = sequence
end

def expected_lock_error?(error)
  current = error
  while current
    return true if current.class.name.match?(/Busy|Locked/)

    current = current.respond_to?(:cause) ? current.cause : nil
  end
  false
end

def heavy_cte(rows)
  ActiveRecord::Base.connection.select_value(<<~SQL).to_i
    with recursive
      input(row_count, multiplier, salt, modulus) as (values(#{rows}, #{HEAVY_CTE_MULTIPLIER}, #{rows}, #{HEAVY_MODULUS})),
      work(n) as (
        select 1
        union all
        select n + 1 from work, input where n < input.row_count
      ),
      amplify(m) as (
        select 1
        union all
        select m + 1 from amplify, input where m < input.multiplier
      )
    select sum(((work.n * amplify.m) + input.salt) % input.modulus)
    from work
    join amplify
    join input
  SQL
end

def select_all_model_decode(rows)
  count = 0
  check = 0
  BenchmarkRow.order(:id).find_each(batch_size: 1_000) do |row|
    count += 1
    check += row.id + row.counter + row.payload.length
  end

  raise "select all returned #{count} rows, expected #{rows}" unless count == rows

  check
end

def profile_update_attempts_per_worker(rows)
  [rows, MAX_PROFILE_UPDATE_ATTEMPTS_PER_WORKER].min
end

main
