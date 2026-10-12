-module(sqlite_tests_ffi).
-export([
    argv/0,
    monotonic_microsecond/0,
    seed_app_request_data/1,
    app_admin_item_edit_requests/2,
    app_admin_item_update_requests/2,
    concurrent_main/4
]).

argv() ->
    [unicode:characters_to_binary(Arg) || Arg <- init:get_plain_arguments()].

monotonic_microsecond() ->
    erlang:monotonic_time(microsecond).

seed_app_request_data(Connection) ->
    Sql = <<"drop table if exists app_users;
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

        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 100
        )
        insert into app_events (id, club_id, name, counter)
        select id, 418, 'Event ' || id, 0 from seed;

        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 20
        )
        insert into app_sponsors (id, club_id, name) select id, 418, 'Sponsor ' || id from seed;
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 30
        )
        insert into app_tags (id, club_id, name) select id, 418, 'Tag ' || id from seed;
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 12
        )
        insert into app_fees (id, club_id, name, active)
        select id, case id % 3 when 0 then 403 when 1 then 411 else 418 end, 'Fee ' || id, 1 from seed;
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 15
        )
        insert into app_products (id, club_id, active, product_type, name)
        select id, 418, 1, case when id % 2 = 0 then 'addon' else 'both' end, 'Product ' || id from seed;
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 300
        )
        insert into app_addons (id, addonable_id, addonable_type, addable_kind, addable_id, position)
        select id, ((id - 1) % 100) + 1, 'Event', case when id % 2 = 0 then 'Product' else 'Fee' end, ((id - 1) % 12) + 1, id % 3 from seed;
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 10
        )
        insert into app_custom_fields (id, club_id, position) select id, 418, id from seed;
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 200
        )
        insert into app_event_custom_fields (id, event_id, position) select id, ((id - 1) % 100) + 1, id % 5 from seed;
        insert into app_discounts (id, club_id, active) values (1, 418, 1), (2, 418, 1), (3, 418, 0);
        with recursive seed(id) as (
            values(1)
            union all
            select id + 1 from seed where id < 200
        )
        insert into app_discount_items (id, item_id, item_type, discount_id) select id, ((id - 1) % 100) + 1, 'Event', ((id - 1) % 2) + 1 from seed;">>,
    case esqlite3:exec(Connection, Sql) of
        ok -> {ok, 100};
        {error, Code} -> to_sqlight_error(Connection, {seed_app_request_failed, Code})
    end.

app_admin_item_edit_requests(Connection, Rows) ->
    app_request_loop(Connection, Rows, fun app_admin_item_edit_request/3).

app_admin_item_update_requests(Connection, Rows) ->
    app_request_loop(Connection, Rows, fun app_admin_item_update_request/3).

app_request_loop(_Connection, Rows, _Fun) when Rows =< 0 ->
    {ok, 0};
app_request_loop(Connection, Rows, Fun) ->
    app_request_loop(Connection, Rows, Fun, 1, 0).

app_request_loop(_Connection, Rows, _Fun, I, Check) when I > Rows ->
    {ok, Check};
app_request_loop(Connection, Rows, Fun, I, Check) ->
    EventId = ((I - 1) rem 100) + 1,
    case Fun(Connection, I, EventId) of
        {ok, RequestCheck} -> app_request_loop(Connection, Rows, Fun, I + 1, Check + RequestCheck);
        {error, _Reason} = Error -> Error
    end.

app_admin_item_edit_request(Connection, _I, EventId) ->
    Queries = [
        {<<"select id from app_users where id = ?">>, [1]},
        {<<"select id from app_clubs where subdomain = ?">>, [<<"demo">>]},
        {<<"select id from app_events where club_id = ? and id = ?">>, [418, EventId]},
        {<<"select count(*) from app_sponsors where club_id = ?">>, [418]},
        {<<"select count(*) from app_tags where club_id = ?">>, [418]},
        {<<"select count(*) from app_taxes where province = ?">>, [<<"ON">>]},
        {<<"with recursive parents(id, parent_id) as (
            select id, parent_id from app_clubs where id = ?
            union all
            select c.id, c.parent_id from app_clubs c inner join parents p on p.parent_id = c.id
        ) select coalesce(sum(id), 0) from parents">>, [418]},
        {<<"select count(*) from app_fees where club_id in (?, ?, ?) and active = ?">>, [418, 411, 403, 1]},
        {<<"select count(*) from app_products where club_id = ? and active = ? and product_type in (?, ?)">>, [418, 1, <<"addon">>, <<"both">>]},
        {<<"select count(*) from app_addons where addonable_id = ? and addonable_type = ?">>, [EventId, <<"Event">>]},
        {<<"select id from app_fees where id = ?">>, [1]},
        {<<"select id from app_clubs where id = ?">>, [403]},
        {<<"select id from app_clubs where id = ?">>, [418]},
        {<<"select id from app_products where id = ?">>, [1]},
        {<<"select id from app_fees where id = ?">>, [2]},
        {<<"select count(*) from app_custom_fields where club_id = ?">>, [418]},
        {<<"select count(*) from app_event_custom_fields where event_id = ?">>, [EventId]},
        {<<"select count(*) from app_custom_fields where club_id = ?">>, [418]},
        {<<"select count(*) from app_discounts where club_id = ? and active = ?">>, [418, 1]},
        {<<"select count(*) from app_discount_items where item_id = ? and item_type = ?">>, [EventId, <<"Event">>]},
        {<<"select count(*) from app_discounts where club_id = ? and active = ?">>, [418, 1]},
        {<<"select id from app_branding_palettes where id = ?">>, [1]},
        {<<"select count(*) from app_admin_alerts where (country = ? or country is null) and (club_type = ? or club_type is null)">>, [<<"Canada">>, <<"club">>]},
        {<<"select count(*) from app_config_problems where club_id = ? and ignored = ?">>, [418, 0]},
        {<<"select count(*) from app_events where club_id = ?">>, [418]},
        {<<"select counter from app_events where id = ?">>, [EventId]}
    ],
    run_integer_queries(Connection, Queries, 0).

app_admin_item_update_request(Connection, I, EventId) ->
    app_admin_item_update_request(Connection, <<"begin">>, I, EventId).

%% Begin is <<"begin">> for the sequential case and <<"begin immediate">> when
%% several workers write at once (see run_concurrent/5).
app_admin_item_update_request(Connection, Begin, I, EventId) ->
    %% BEGIN and COMMIT go through the statement cache too, so every statement
    %% in the request is reused, like the other runners.
    case cached_q(Connection, Begin, []) of
        [] ->
            Queries = [
                {<<"select id from app_users where id = ?">>, [1]},
                {<<"select id from app_clubs where subdomain = ?">>, [<<"demo">>]},
                {<<"select id from app_events where club_id = ? and id = ?">>, [418, EventId]},
                {<<"select count(*) from app_addons where addonable_id = ? and addonable_type = ?">>, [EventId, <<"Event">>]},
                {<<"select count(*) from app_discount_items where item_id = ? and item_type = ?">>, [EventId, <<"Event">>]},
                {<<"select count(*) from app_tags where club_id = ?">>, [418]}
            ],
            case run_integer_queries(Connection, Queries, 0) of
                {ok, Check} ->
                    case cached_q(Connection, <<"update app_events set counter = counter + 1, name = ? where id = ?">>, [
                        <<"Updated Event ", (integer_to_binary(I))/binary>>,
                        EventId
                    ]) of
                        [] ->
                            case cached_q(Connection, <<"commit">>, []) of
                                [] -> {ok, Check + EventId};
                                {error, Code} -> to_sqlight_error(Connection, {app_update_commit_failed, Code})
                            end;
                        {error, Code} ->
                            _ = esqlite3:exec(Connection, <<"rollback;">>),
                            to_sqlight_error(Connection, {app_update_failed, Code});
                        Rows ->
                            _ = esqlite3:exec(Connection, <<"rollback;">>),
                            generic_sqlight_error({app_update_wrong_result, Rows})
                    end;
                {error, _Reason} = Error ->
                    _ = esqlite3:exec(Connection, <<"rollback;">>),
                    Error
            end;
        {error, Code} ->
            to_sqlight_error(Connection, {app_update_begin_failed, Code})
    end.

run_integer_queries(_Connection, [], Check) ->
    {ok, Check};
run_integer_queries(Connection, [{Sql, Bindings} | Rest], Check) ->
    case cached_q(Connection, Sql, Bindings) of
        [[Value]] when is_integer(Value) ->
            run_integer_queries(Connection, Rest, Check + Value);
        {error, Code} ->
            to_sqlight_error(Connection, {app_request_query_failed, Sql, Code});
        Rows ->
            generic_sqlight_error({app_request_wrong_result, Sql, Rows})
    end.

%% esqlite3:q/3 compiles the statement on every call. Keep one compiled
%% statement per connection and SQL text in the process dictionary instead, so
%% this path caches statements like the Rust and Bun runners. The cache only
%% stays warm because this runner handles every request in one process; a web
%% server that runs each request in its own process would start cold each time.
cached_q(Connection, Sql, Bindings) ->
    case cached_statement(Connection, Sql) of
        {ok, Statement} ->
            Result =
                case esqlite3:bind(Statement, Bindings) of
                    ok -> fetch_rows(Statement, []);
                    {error, _} = Error -> Error
                end,
            _ = esqlite3:reset(Statement),
            Result;
        {error, _} = Error ->
            Error
    end.

cached_statement(Connection, Sql) ->
    Key = {sqlite_tests_statement, Connection, Sql},
    case get(Key) of
        undefined ->
            case esqlite3:prepare(Connection, Sql) of
                {ok, Statement} = Prepared ->
                    put(Key, Statement),
                    Prepared;
                {error, _} = Error ->
                    Error
            end;
        Statement ->
            {ok, Statement}
    end.

fetch_rows(Statement, Rows) ->
    case esqlite3:step(Statement) of
        Row when is_list(Row) -> fetch_rows(Statement, [Row | Rows]);
        '$done' -> lists:reverse(Rows);
        %% The busy timeout expired without getting the lock.
        '$busy' -> {error, busy};
        {error, _} = Error -> Error
    end.

to_sqlight_error(Connection, Code) when is_integer(Code) ->
    #{errmsg := Message, error_offset := Offset} = esqlite3:error_info(Connection),
    {error, {sqlight_error, sqlight:error_code_from_int(Code), Message, Offset}};
to_sqlight_error(_Connection, Reason) ->
    generic_sqlight_error(Reason).

generic_sqlight_error(Reason) ->
    Message = unicode:characters_to_binary(io_lib:format("prepared benchmark failed: ~p", [Reason])),
    {error, {sqlight_error, generic_error, Message, -1}}.

%% Concurrent mode: W workers, each a BEAM process with its own connection and
%% statement cache, run one workload for a fixed time. Every worker opens its
%% connection before the clock starts, warms up, then records the latency of
%% each request that starts inside the measured window. Writes use BEGIN
%% IMMEDIATE: a deferred transaction that reads and then writes fails at once
%% with SQLITE_BUSY if another worker committed in between, without waiting on
%% busy_timeout.

concurrent_main(Path, DurationArg, WarmupArg, WorkersArg) ->
    Duration = to_number(DurationArg),
    Warmup = to_number(WarmupArg),
    Workers = [binary_to_integer(W) || W <- binary:split(WorkersArg, <<",">>, [global])],
    [file:delete(<<Path/binary, Suffix/binary>>) || Suffix <- [<<>>, <<"-wal">>, <<"-shm">>]],
    Seed = open_connection(Path),
    {ok, _} = seed_app_request_data(Seed),
    ok = esqlite3:close(Seed),
    io:format("case,workers,seconds,requests,requests_per_second,p50_us,p95_us,p99_us,max_us,errors~n"),
    lists:foreach(
        fun(Workload) ->
            [run_concurrent(Path, Workload, Count, Duration, Warmup) || Count <- Workers]
        end,
        [read, write, mixed]
    ),
    nil.

to_number(Binary) ->
    try binary_to_float(Binary)
    catch error:badarg -> float(binary_to_integer(Binary))
    end.

open_connection(Path) ->
    {ok, Connection} = esqlite3:open(binary_to_list(Path)),
    %% Set the busy timeout before anything that takes a lock, so connections
    %% opened at the same moment wait for each other instead of failing.
    ok = esqlite3:exec(Connection, <<"pragma busy_timeout = 5000;">>),
    ok = esqlite3:exec(Connection, <<"pragma journal_mode = WAL;">>),
    ok = esqlite3:exec(Connection, <<"pragma synchronous = NORMAL;">>),
    ok = esqlite3:exec(Connection, <<"pragma foreign_keys = ON;">>),
    Connection.

run_concurrent(Path, Workload, Count, Duration, Warmup) ->
    Coordinator = self(),
    Pids = [
        spawn_link(fun() -> concurrent_worker(Coordinator, Path, Workload, Index) end)
     || Index <- lists:seq(0, Count - 1)
    ],
    [receive {ready, Pid} -> ok end || Pid <- Pids],
    WarmUntil = erlang:monotonic_time(microsecond) + round(Warmup * 1000000),
    MeasureUntil = WarmUntil + round(Duration * 1000000),
    [Pid ! {go, WarmUntil, MeasureUntil} || Pid <- Pids],
    Results = [receive {latencies, Pid, L, E} -> {L, E} end || Pid <- Pids],
    Latencies = lists:append([L || {L, _} <- Results]),
    Errors = lists:sum([E || {_, E} <- Results]),
    Sorted = list_to_tuple(lists:sort(Latencies)),
    Total = tuple_size(Sorted),
    Percentile = fun
        (_) when Total =:= 0 -> 0;
        (P) -> element(trunc((Total - 1) * P) + 1, Sorted)
    end,
    Max = case Total of 0 -> 0; _ -> element(Total, Sorted) end,
    io:format("gleam_esqlite/concurrent/~s,~b,~s,~b,~b,~b,~b,~b,~b,~b~n", [
        Workload, Count, format_seconds(Duration), Total, round(Total / Duration),
        Percentile(0.50), Percentile(0.95), Percentile(0.99), Max, Errors
    ]).

format_seconds(Seconds) when Seconds == trunc(Seconds) -> integer_to_list(trunc(Seconds));
format_seconds(Seconds) -> float_to_list(Seconds, [{decimals, 3}, compact]).

concurrent_worker(Coordinator, Path, Workload, Index) ->
    Connection = open_connection(Path),
    Coordinator ! {ready, self()},
    receive {go, WarmUntil, MeasureUntil} -> ok end,
    %% Offset each worker's event ids so workers don't all hit the same rows.
    {Latencies, Errors} =
        concurrent_loop(Connection, Workload, Index * 37, WarmUntil, MeasureUntil, [], 0),
    ok = esqlite3:close(Connection),
    Coordinator ! {latencies, self(), Latencies, Errors}.

%% A request that fails, in practice a write whose busy timeout expired, counts
%% as an error instead of stopping the run. Other runners never hit this: their
%% lock waits sleep on their own OS threads. Here every lock wait sleeps on a
%% dirty I/O scheduler thread, and once waiting writers occupy all of them, the
%% writer holding the lock can't run its COMMIT until the timeouts expire.
concurrent_loop(Connection, Workload, Sequence0, WarmUntil, MeasureUntil, Acc, Errors) ->
    Start = erlang:monotonic_time(microsecond),
    case Start >= MeasureUntil of
        true ->
            {Acc, Errors};
        false ->
            Sequence = Sequence0 + 1,
            EventId = ((Sequence - 1) rem 100) + 1,
            Write = Workload =:= write orelse (Workload =:= mixed andalso Sequence rem 10 =:= 0),
            Result =
                case Write of
                    true -> app_admin_item_update_request(Connection, <<"begin immediate">>, Sequence, EventId);
                    false -> app_admin_item_edit_request(Connection, Sequence, EventId)
                end,
            Measured = Start >= WarmUntil,
            case Result of
                {ok, _} when Measured ->
                    Latency = erlang:monotonic_time(microsecond) - Start,
                    concurrent_loop(Connection, Workload, Sequence, WarmUntil, MeasureUntil, [Latency | Acc], Errors);
                {ok, _} ->
                    concurrent_loop(Connection, Workload, Sequence, WarmUntil, MeasureUntil, Acc, Errors);
                %% Count errors during warm-up too: a stalled request that started
                %% there would otherwise leave no trace.
                {error, _} ->
                    concurrent_loop(Connection, Workload, Sequence, WarmUntil, MeasureUntil, Acc, Errors + 1)
            end
    end.
