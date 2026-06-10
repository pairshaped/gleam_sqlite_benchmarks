-module(postgres_tests_ffi).

-export([argv/0, run/1, decode_int_row/1]).

-define(POOL, postgres_tests_pool).
-define(QUERY_TIMEOUT, 60000).
-define(HEARTBEAT_PERIOD_MICROS, 1000).
-define(SENDFILE_BASELINE_MILLIS, 500).
-define(READ_FILE_BASELINE_MILLIS, 500).

argv() ->
    sqlite_tests_ffi:argv().

run(Rows) when is_integer(Rows), Rows > 0 ->
    io:format("case,items,micros,us_per_item,check~n", []),
    measure_sendfile_baseline(),
    measure_read_file_baseline(),
    case start_postgres_pools() of
        ok ->
            case run_benchmarks(Rows) of
                ok -> nil;
                {error, Reason} ->
                    io:format(standard_error, "benchmark failed: ~p~n", [Reason]),
                    nil
            end;
        {error, Reason} ->
            io:format(standard_error, "postgres setup failed: ~p~n", [Reason]),
            nil
    end;
run(Rows) ->
    io:format(standard_error, "invalid row count: ~p~n", [Rows]),
    nil.

start_postgres_pools() ->
    case application:ensure_all_started(pgo) of
        {ok, _Apps} ->
            start_pool(?POOL, postgres_config(pool_size(), ?POOL));
        {error, _Reason} = Error ->
            Error
    end.

start_pool(_Pool, Config) ->
    case pog:start(Config) of
        {ok, _Started} -> ok;
        {error, {init_exited, {abnormal, {already_started, _Pid}}}} -> ok;
        {error, {init_exited, {abnormal, {error, {already_started, _Pid}}}}} -> ok;
        {error, _Reason} = Error -> Error
    end.

pool_size() ->
    5.

postgres_config(PoolSize, PoolName) ->
    Config0 = pog:default_config(PoolName),
    Config1 = pog:host(Config0, unicode:characters_to_binary(env_string("PGHOST", "/tmp"))),
    Config2 = pog:port(Config1, env_int("PGPORT", 5432)),
    Config3 = pog:user(Config2, unicode:characters_to_binary(env_string("PGUSER", default_user()))),
    Config4 = pog:database(Config3, unicode:characters_to_binary(env_string("PGDATABASE", "postgres"))),
    Config5 = pog:pool_size(Config4, PoolSize),
    Config6 = pog:queue_target(Config5, ?QUERY_TIMEOUT),
    Config7 = pog:queue_interval(Config6, 1000),
    Config8 = pog:idle_interval(Config7, 60000),
    Config9 = pog:trace(Config8, false),
    Config10 = pog:connection_parameter(
        Config9,
        <<"application_name">>,
        <<"sqlite_tests_postgres_pog_benchmark">>
    ),
    case os:getenv("PGPASSWORD") of
        false -> Config10;
        "" -> Config10;
        Password -> pog:password(Config10, {some, unicode:characters_to_binary(Password)})
    end.

default_user() ->
    case os:getenv("USER") of
        false -> "postgres";
        "" -> "postgres";
        User -> User
    end.

env_string(Name, Default) ->
    case os:getenv(Name) of
        false -> Default;
        "" -> Default;
        Value -> Value
    end.

env_int(Name, Default) ->
    case os:getenv(Name) of
        false -> Default;
        "" -> Default;
        Value ->
            case string:to_integer(Value) of
                {Int, ""} when Int > 0 -> Int;
                _ -> Default
            end
    end.
run_benchmarks(Rows) ->
    with_ok([
        fun() -> measure("app_request/seed_dummy_data", 1, fun seed_app_request_data/0) end,
        fun() -> measure("app_request/admin_item_edit", Rows, fun() -> app_admin_item_edit_requests(Rows) end) end,
        fun() -> measure("batched_request/admin_item_edit", Rows, fun() -> batched_admin_item_edit_requests(Rows) end) end,
        fun() -> measure("app_request/admin_item_update", Rows, fun() -> app_admin_item_update_requests(Rows) end) end,
        fun() -> measure("batched_request/admin_item_update", Rows, fun() -> batched_admin_item_update_requests(Rows) end) end,
        fun() -> measure_with_probes("probed_app_request/seed_dummy_data", 1, fun seed_app_request_data/0) end,
        fun() -> measure_with_probes("probed_app_request/admin_item_edit", Rows, fun() -> app_admin_item_edit_requests(Rows) end) end,
        fun() -> measure_with_probes("probed_batched_request/admin_item_edit", Rows, fun() -> batched_admin_item_edit_requests(Rows) end) end,
        fun() -> measure_with_probes("probed_app_request/admin_item_update", Rows, fun() -> app_admin_item_update_requests(Rows) end) end,
        fun() -> measure_with_probes("probed_batched_request/admin_item_update", Rows, fun() -> batched_admin_item_update_requests(Rows) end) end
    ]).

with_ok([]) ->
    ok;
with_ok([Step | Rest]) ->
    case Step() of
        {ok, _Check} -> with_ok(Rest);
        ok -> with_ok(Rest);
        {error, _Reason} = Error -> Error
    end.
run_queries([]) ->
    ok;
run_queries([Sql | Rest]) ->
    case exec_query(Sql, []) of
        {ok, _Result} -> run_queries(Rest);
        {error, _Reason} = Error -> Error
    end.
seed_app_request_data() ->
    Queries = [
        "drop table if exists app_discount_items",
        "drop table if exists app_discounts",
        "drop table if exists app_event_custom_fields",
        "drop table if exists app_custom_fields",
        "drop table if exists app_addons",
        "drop table if exists app_products",
        "drop table if exists app_fees",
        "drop table if exists app_taxes",
        "drop table if exists app_tags",
        "drop table if exists app_sponsors",
        "drop table if exists app_events",
        "drop table if exists app_config_problems",
        "drop table if exists app_admin_alerts",
        "drop table if exists app_branding_palettes",
        "drop table if exists app_clubs",
        "drop table if exists app_users",
        "create table app_users (id integer primary key, name text not null)",
        "create table app_clubs (id integer primary key, parent_id integer, subdomain text not null, province text not null)",
        "create index app_clubs_subdomain on app_clubs(subdomain)",
        "create index app_clubs_parent_id on app_clubs(parent_id)",
        "create table app_events (id integer primary key, club_id integer not null, name text not null, counter integer not null)",
        "create index app_events_club_id on app_events(club_id)",
        "create table app_sponsors (id integer primary key, club_id integer not null, name text not null)",
        "create index app_sponsors_club_id on app_sponsors(club_id)",
        "create table app_tags (id integer primary key, club_id integer not null, name text not null)",
        "create index app_tags_club_id on app_tags(club_id)",
        "create table app_taxes (id integer primary key, province text not null, name text not null)",
        "create index app_taxes_province on app_taxes(province)",
        "create table app_fees (id integer primary key, club_id integer not null, name text not null, active integer not null)",
        "create index app_fees_club_id on app_fees(club_id, active)",
        "create table app_products (id integer primary key, club_id integer not null, active integer not null, product_type text not null, name text not null)",
        "create index app_products_club_type on app_products(club_id, active, product_type)",
        "create table app_addons (id integer primary key, addonable_id integer not null, addonable_type text not null, addable_kind text not null, addable_id integer not null, position integer not null)",
        "create index app_addons_addonable on app_addons(addonable_id, addonable_type)",
        "create table app_custom_fields (id integer primary key, club_id integer not null, position integer not null)",
        "create index app_custom_fields_club_id on app_custom_fields(club_id)",
        "create table app_event_custom_fields (id integer primary key, event_id integer not null, position integer not null)",
        "create index app_event_custom_fields_event_id on app_event_custom_fields(event_id)",
        "create table app_discounts (id integer primary key, club_id integer not null, active integer not null)",
        "create index app_discounts_club_id on app_discounts(club_id, active)",
        "create table app_discount_items (id integer primary key, item_id integer not null, item_type text not null, discount_id integer not null)",
        "create index app_discount_items_item on app_discount_items(item_id, item_type)",
        "create table app_branding_palettes (id integer primary key, slug text not null)",
        "create table app_admin_alerts (id integer primary key, country text, club_type text)",
        "create table app_config_problems (id integer primary key, club_id integer not null, ignored integer not null)",
        "create index app_config_problems_club_id on app_config_problems(club_id, ignored)"
    ],
    case run_queries(Queries) of
        ok -> seed_app_request_rows();
        {error, _Reason} = Error -> Error
    end.

seed_app_request_rows() ->
    Inserts = [
        {"insert into app_users (id, name) values ($1, $2)", [1, <<"Admin">>]},
        {"insert into app_clubs (id, parent_id, subdomain, province) values ($1, null, $2, $3)", [403, <<"canada">>, <<"ON">>]},
        {"insert into app_clubs (id, parent_id, subdomain, province) values ($1, $2, $3, $4)", [411, 403, <<"ontario">>, <<"ON">>]},
        {"insert into app_clubs (id, parent_id, subdomain, province) values ($1, $2, $3, $4)", [418, 411, <<"demo">>, <<"ON">>]},
        {"insert into app_branding_palettes (id, slug) values ($1, $2)", [1, <<"default">>]},
        {"insert into app_admin_alerts (id, country, club_type) values ($1, $2, $3)", [330, <<"Canada">>, <<"club">>]},
        {"insert into app_config_problems (id, club_id, ignored) values ($1, $2, $3)", [1, 418, 0]},
        {"insert into app_taxes (id, province, name) values ($1, $2, $3), ($4, $5, $6)", [1, <<"ON">>, <<"HST">>, 2, <<"ON">>, <<"GST">>]},
        {"insert into app_events (id, club_id, name, counter) select id, 418, 'Event ' || id, 0 from generate_series(1, 100) as seed(id)", []},
        {"insert into app_sponsors (id, club_id, name) select id, 418, 'Sponsor ' || id from generate_series(1, 20) as seed(id)", []},
        {"insert into app_tags (id, club_id, name) select id, 418, 'Tag ' || id from generate_series(1, 30) as seed(id)", []},
        {"insert into app_fees (id, club_id, name, active) select id, case id % 3 when 0 then 403 when 1 then 411 else 418 end, 'Fee ' || id, 1 from generate_series(1, 12) as seed(id)", []},
        {"insert into app_products (id, club_id, active, product_type, name) select id, 418, 1, case when id % 2 = 0 then 'addon' else 'both' end, 'Product ' || id from generate_series(1, 15) as seed(id)", []},
        {"insert into app_addons (id, addonable_id, addonable_type, addable_kind, addable_id, position) select id, ((id - 1) % 100) + 1, 'Event', case when id % 2 = 0 then 'Product' else 'Fee' end, ((id - 1) % 12) + 1, id % 3 from generate_series(1, 300) as seed(id)", []},
        {"insert into app_custom_fields (id, club_id, position) select id, 418, id from generate_series(1, 10) as seed(id)", []},
        {"insert into app_event_custom_fields (id, event_id, position) select id, ((id - 1) % 100) + 1, id % 5 from generate_series(1, 200) as seed(id)", []},
        {"insert into app_discounts (id, club_id, active) values (1, 418, 1), (2, 418, 1), (3, 418, 0)", []},
        {"insert into app_discount_items (id, item_id, item_type, discount_id) select id, ((id - 1) % 100) + 1, 'Event', ((id - 1) % 2) + 1 from generate_series(1, 200) as seed(id)", []}
    ],
    case run_param_queries(Inserts) of
        ok -> {ok, 100};
        {error, _Reason} = Error -> Error
    end.

run_param_queries([]) ->
    ok;
run_param_queries([{Sql, Params} | Rest]) ->
    case exec_query(Sql, Params) of
        {ok, _Result} -> run_param_queries(Rest);
        {error, _Reason} = Error -> Error
    end.

app_admin_item_edit_requests(Rows) ->
    app_request_loop(Rows, fun app_admin_item_edit_request/2).

app_admin_item_update_requests(Rows) ->
    app_request_loop(Rows, fun app_admin_item_update_request/2).

batched_admin_item_edit_requests(Rows) ->
    app_request_loop(Rows, fun batched_admin_item_edit_request/2).

batched_admin_item_update_requests(Rows) ->
    app_request_loop(Rows, fun batched_admin_item_update_request/2).

app_request_loop(Rows, Fun) ->
    loop(1, Rows, 0, fun(I, Check) ->
        EventId = ((I - 1) rem 100) + 1,
        case Fun(I, EventId) of
            {ok, RequestCheck} -> {ok, Check + RequestCheck};
            {error, _Reason} = Error -> Error
        end
    end).

app_admin_item_edit_request(_I, EventId) ->
    Queries = [
        {"select id from app_users where id = $1", [1]},
        {"select id from app_clubs where subdomain = $1", [<<"demo">>]},
        {"select id from app_events where club_id = $1 and id = $2", [418, EventId]},
        {"select count(*) from app_sponsors where club_id = $1", [418]},
        {"select count(*) from app_tags where club_id = $1", [418]},
        {"select count(*) from app_taxes where province = $1", [<<"ON">>]},
        {"with recursive parents(id, parent_id) as (
            select id, parent_id from app_clubs where id = $1
            union all
            select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
        ) select coalesce(sum(id), 0) from parents", [418]},
        {"select count(*) from app_fees where club_id in ($1, $2, $3) and active = $4", [418, 411, 403, 1]},
        {"select count(*) from app_products where club_id = $1 and active = $2 and product_type in ($3, $4)", [418, 1, <<"addon">>, <<"both">>]},
        {"select count(*) from app_addons where addonable_id = $1 and addonable_type = $2", [EventId, <<"Event">>]},
        {"select id from app_fees where id = $1", [1]},
        {"select id from app_clubs where id = $1", [403]},
        {"select id from app_clubs where id = $1", [418]},
        {"select id from app_products where id = $1", [1]},
        {"select id from app_fees where id = $1", [2]},
        {"select count(*) from app_custom_fields where club_id = $1", [418]},
        {"select count(*) from app_event_custom_fields where event_id = $1", [EventId]},
        {"select count(*) from app_custom_fields where club_id = $1", [418]},
        {"select count(*) from app_discounts where club_id = $1 and active = $2", [418, 1]},
        {"select count(*) from app_discount_items where item_id = $1 and item_type = $2", [EventId, <<"Event">>]},
        {"select count(*) from app_discounts where club_id = $1 and active = $2", [418, 1]},
        {"select id from app_branding_palettes where id = $1", [1]},
        {"select count(*) from app_admin_alerts where (country = $1 or country is null) and (club_type = $2 or club_type is null)", [<<"Canada">>, <<"club">>]},
        {"select count(*) from app_config_problems where club_id = $1 and ignored = $2", [418, 0]},
        {"select count(*) from app_events where club_id = $1", [418]},
        {"select counter from app_events where id = $1", [EventId]}
    ],
    run_integer_queries(Queries, 0).

app_admin_item_update_request(I, EventId) ->
    transaction(fun() ->
        Queries = [
            {"select id from app_users where id = $1", [1]},
            {"select id from app_clubs where subdomain = $1", [<<"demo">>]},
            {"select id from app_events where club_id = $1 and id = $2", [418, EventId]},
            {"select count(*) from app_addons where addonable_id = $1 and addonable_type = $2", [EventId, <<"Event">>]},
            {"select count(*) from app_discount_items where item_id = $1 and item_type = $2", [EventId, <<"Event">>]},
            {"select count(*) from app_tags where club_id = $1", [418]}
        ],
        case run_integer_queries(Queries, 0) of
            {ok, Check} ->
                Name = <<"Updated Event ", (integer_to_binary(I))/binary>>,
                case exec_query("update app_events set counter = counter + 1, name = $1 where id = $2", [Name, EventId]) of
                    {ok, _Result} -> {ok, Check + EventId};
                    {error, _Reason} = Error -> Error
                end;
            {error, _Reason} = Error ->
                Error
        end
    end).

batched_admin_item_edit_request(_I, EventId) ->
    one_integer_query(
        "select (
            (select id from app_users where id = 1) +
            (select id from app_clubs where subdomain = 'demo') +
            (select id from app_events where club_id = 418 and id = $1) +
            (select count(*) from app_sponsors where club_id = 418) +
            (select count(*) from app_tags where club_id = 418) +
            (select count(*) from app_taxes where province = 'ON') +
            (with recursive parents(id, parent_id) as (
                select id, parent_id from app_clubs where id = 418
                union all
                select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
            ) select coalesce(sum(id), 0) from parents) +
            (select count(*) from app_fees where club_id in (418, 411, 403) and active = 1) +
            (select count(*) from app_products where club_id = 418 and active = 1 and product_type in ('addon', 'both')) +
            (select count(*) from app_addons where addonable_id = $1 and addonable_type = 'Event') +
            (select id from app_fees where id = 1) +
            (select id from app_clubs where id = 403) +
            (select id from app_clubs where id = 418) +
            (select id from app_products where id = 1) +
            (select id from app_fees where id = 2) +
            (select count(*) from app_custom_fields where club_id = 418) +
            (select count(*) from app_event_custom_fields where event_id = $1) +
            (select count(*) from app_custom_fields where club_id = 418) +
            (select count(*) from app_discounts where club_id = 418 and active = 1) +
            (select count(*) from app_discount_items where item_id = $1 and item_type = 'Event') +
            (select count(*) from app_discounts where club_id = 418 and active = 1) +
            (select id from app_branding_palettes where id = 1) +
            (select count(*) from app_admin_alerts where (country = 'Canada' or country is null) and (club_type = 'club' or club_type is null)) +
            (select count(*) from app_config_problems where club_id = 418 and ignored = 0) +
            (select count(*) from app_events where club_id = 418) +
            (select counter from app_events where id = $1)
        )::bigint",
        [EventId]
    ).

batched_admin_item_update_request(I, EventId) ->
    transaction(fun() ->
        Name = <<"Updated Event ", (integer_to_binary(I))/binary>>,
        one_integer_query(
            "with updated as (
                update app_events
                set counter = counter + 1, name = $1
                where id = $2
                returning id
            )
            select (
                (select id from app_users where id = 1) +
                (select id from app_clubs where subdomain = 'demo') +
                (select id from app_events where club_id = 418 and id = $2) +
                (select count(*) from app_addons where addonable_id = $2 and addonable_type = 'Event') +
                (select count(*) from app_discount_items where item_id = $2 and item_type = 'Event') +
                (select count(*) from app_tags where club_id = 418) +
                (select id from updated)
            )::bigint",
            [Name, EventId]
        )
    end).

run_integer_queries([], Check) ->
    {ok, Check};
run_integer_queries([{Sql, Params} | Rest], Check) ->
    case one_integer_query(Sql, Params) of
        {ok, Value} -> run_integer_queries(Rest, Check + Value);
        {error, _Reason} = Error -> Error
    end.
one_integer_query(Sql, Params) ->
    one_integer_query(?POOL, Sql, Params).

one_integer_query(Pool, Sql, Params) ->
    case pog_execute(Pool, Sql, Params, {some, int_row_decoder()}) of
        {ok, #{rows := [Value]}} when is_integer(Value) ->
            {ok, Value};
        {ok, Other} ->
            {error, {expected_one_integer_row, Other}};
        {error, _Reason} = Error ->
            Error
    end.

exec_query(Sql, Params) ->
    exec_query(?POOL, Sql, Params).

exec_query(Pool, Sql, Params) ->
    pog_execute(Pool, Sql, Params, none).

transaction(Fun) ->
    case pog:transaction({pool, ?POOL}, fun(Connection) ->
        put(postgres_tests_pog_transaction_connection, Connection),
        try
            Fun()
        after
            erase(postgres_tests_pog_transaction_connection)
        end
    end) of
        {ok, Result} -> {ok, Result};
        {error, _Reason} = Error -> Error
    end.

pog_execute(Pool, Sql, Params, Decoder) ->
    Query0 = pog:'query'(unicode:characters_to_binary(Sql)),
    Query1 = pog:timeout(Query0, ?QUERY_TIMEOUT),
    Query2 = case Decoder of
        none -> Query1;
        {some, RowDecoder} -> pog:returning(Query1, RowDecoder)
    end,
    Query = lists:foldl(fun(Param, Acc) ->
        pog:parameter(Acc, pog_value(Param))
    end, Query2, Params),
    case pog:execute(Query, pog_connection(Pool)) of
        {ok, {returned, Count, Rows}} ->
            {ok, #{command => pog, num_rows => Count, rows => Rows}};
        {error, _Reason} = Error ->
            Error
    end.

pog_connection(Pool) ->
    case get(postgres_tests_pog_transaction_connection) of
        undefined -> {pool, Pool};
        Connection -> Connection
    end.

pog_value(Value) when is_integer(Value) ->
    pog:int(Value);
pog_value(Value) when is_binary(Value) ->
    pog:text(Value).

int_row_decoder() ->
    gleam@dynamic@decode:new_primitive_decoder(<<"postgres int row">>, fun decode_int_row/1).
decode_int_row({Value}) when is_integer(Value) ->
    {ok, Value};
decode_int_row([Value]) when is_integer(Value) ->
    {ok, Value};
decode_int_row(_Other) ->
    {error, 0}.

loop(I, Rows, Acc, _Fun) when I > Rows ->
    {ok, Acc};
loop(I, Rows, Acc, Fun) ->
    case Fun(I, Acc) of
        {ok, NextAcc} -> loop(I + 1, Rows, NextAcc, Fun);
        {error, _Reason} = Error -> Error
    end.
measure(Name, Items, Work) ->
    Start = sqlite_tests_ffi:monotonic_microsecond(),
    Result = Work(),
    Elapsed = sqlite_tests_ffi:monotonic_microsecond() - Start,
    case Result of
        {ok, Check} ->
            UsPerItem = safe_div(Elapsed, Items),
            print_csv_row(Name, Items, Elapsed, UsPerItem, Check),
            {ok, Check};
        {error, _Reason} = Error ->
            Error
    end.

measure_with_probes(Name, Items, Work) ->
    case measure_with_extra_rows(Name, Items, fun() ->
        case Work() of
            {ok, Check} -> {ok, {Check, []}};
            {error, _Reason} = Error -> Error
        end
    end) of
        {ok, {Check, _ExtraRows}} -> {ok, Check};
        {error, _Reason} = Error -> Error
    end.

measure_with_extra_rows(Name, Items, Work) ->
    SendfileProbe = sqlite_tests_ffi:start_sendfile_probe(),
    ReadFileProbe = sqlite_tests_ffi:start_read_file_probe(),
    Heartbeat = sqlite_tests_ffi:start_heartbeat(?HEARTBEAT_PERIOD_MICROS),
    Start = sqlite_tests_ffi:monotonic_microsecond(),
    Result = Work(),
    Elapsed = sqlite_tests_ffi:monotonic_microsecond() - Start,
    {HeartbeatSamples, HeartbeatMaxDelay, HeartbeatAvgDelay} =
        sqlite_tests_ffi:stop_heartbeat(Heartbeat),
    {
        SendfileAttempts,
        SendfileFailures,
        SendfileMaxLatency,
        SendfileAvgLatency,
        SendfileBytes,
        SendfileFailureCode
    } = sqlite_tests_ffi:stop_sendfile_probe(SendfileProbe),
    {
        ReadFileAttempts,
        ReadFileFailures,
        ReadFileMaxLatency,
        ReadFileAvgLatency,
        ReadFileBytes,
        ReadFileFailureCode
    } = sqlite_tests_ffi:stop_read_file_probe(ReadFileProbe),
    case Result of
        {ok, {Check, ExtraRows}} ->
            UsPerItem = safe_div(Elapsed, Items),
            print_csv_row(Name, Items, Elapsed, UsPerItem, Check),
            lists:foreach(fun({ExtraName, ExtraCheck}) ->
                print_csv_row(ExtraName, Items, Elapsed, UsPerItem, ExtraCheck)
            end, ExtraRows),
            print_csv_row("scheduler/heartbeat/" ++ Name, HeartbeatSamples, HeartbeatMaxDelay, HeartbeatAvgDelay, ?HEARTBEAT_PERIOD_MICROS),
            print_csv_row("io/sendfile/" ++ Name, SendfileAttempts, SendfileMaxLatency, SendfileAvgLatency, SendfileFailures),
            print_csv_row("io/sendfile/bytes/" ++ Name, SendfileAttempts, SendfileMaxLatency, SendfileAvgLatency, SendfileBytes),
            print_csv_row("io/sendfile/failure_code/" ++ Name, SendfileAttempts, SendfileMaxLatency, SendfileAvgLatency, SendfileFailureCode),
            print_csv_row("io/read_file/" ++ Name, ReadFileAttempts, ReadFileMaxLatency, ReadFileAvgLatency, ReadFileFailures),
            print_csv_row("io/read_file/bytes/" ++ Name, ReadFileAttempts, ReadFileMaxLatency, ReadFileAvgLatency, ReadFileBytes),
            print_csv_row("io/read_file/failure_code/" ++ Name, ReadFileAttempts, ReadFileMaxLatency, ReadFileAvgLatency, ReadFileFailureCode),
            {ok, {Check, ExtraRows}};
        {error, _Reason} = Error ->
            Error
    end.

measure_sendfile_baseline() ->
    Probe = sqlite_tests_ffi:start_sendfile_probe(),
    sqlite_tests_ffi:sleep_millisecond(?SENDFILE_BASELINE_MILLIS),
    {Attempts, Failures, MaxLatency, AvgLatency, Bytes, FailureCode} =
        sqlite_tests_ffi:stop_sendfile_probe(Probe),
    print_csv_row("io/sendfile/baseline", Attempts, MaxLatency, AvgLatency, Failures),
    print_csv_row("io/sendfile/bytes/baseline", Attempts, MaxLatency, AvgLatency, Bytes),
    print_csv_row("io/sendfile/failure_code/baseline", Attempts, MaxLatency, AvgLatency, FailureCode).

measure_read_file_baseline() ->
    Probe = sqlite_tests_ffi:start_read_file_probe(),
    sqlite_tests_ffi:sleep_millisecond(?READ_FILE_BASELINE_MILLIS),
    {Attempts, Failures, MaxLatency, AvgLatency, Bytes, FailureCode} =
        sqlite_tests_ffi:stop_read_file_probe(Probe),
    print_csv_row("io/read_file/baseline", Attempts, MaxLatency, AvgLatency, Failures),
    print_csv_row("io/read_file/bytes/baseline", Attempts, MaxLatency, AvgLatency, Bytes),
    print_csv_row("io/read_file/failure_code/baseline", Attempts, MaxLatency, AvgLatency, FailureCode).

print_csv_row(Name, Items, Micros, UsPerItem, Check) ->
    io:format("~s,~B,~B,~B,~B~n", [Name, Items, Micros, UsPerItem, Check]).

safe_div(_Value, 0) ->
    0;
safe_div(Value, Divisor) ->
    Value div Divisor.
