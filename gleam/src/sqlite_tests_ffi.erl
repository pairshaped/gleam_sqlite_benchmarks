-module(sqlite_tests_ffi).
-export([
    argv/0,
    monotonic_microsecond/0,
    sleep_millisecond/1,
    seed_app_request_data/1,
    app_admin_item_edit_requests/2,
    app_admin_item_update_requests/2,
    start_heartbeat/1,
    stop_heartbeat/1,
    start_read_file_probe/0,
    start_sendfile_probe/0,
    stop_read_file_probe/1,
    stop_sendfile_probe/1
]).

-include_lib("kernel/include/file.hrl").

-define(SENDFILE_PROBE_PATH, "sqlite_tests_sendfile_probe.bin").
-define(SENDFILE_PROBE_SIZE, 262144).
-define(READ_FILE_PROBE_PATH, "sqlite_tests_read_file_probe.bin").
-define(READ_FILE_PROBE_SIZE, 262144).

argv() ->
    [unicode:characters_to_binary(Arg) || Arg <- init:get_plain_arguments()].

monotonic_microsecond() ->
    erlang:monotonic_time(microsecond).

sleep_millisecond(Milliseconds) ->
    timer:sleep(Milliseconds),
    nil.

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
    case esqlite3:exec(Connection, <<"begin transaction;">>) of
        ok ->
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
                    case esqlite3:q(Connection, <<"update app_events set counter = counter + 1, name = ? where id = ?">>, [
                        <<"Updated Event ", (integer_to_binary(I))/binary>>,
                        EventId
                    ]) of
                        [] ->
                            case esqlite3:exec(Connection, <<"commit;">>) of
                                ok -> {ok, Check + EventId};
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
    case esqlite3:q(Connection, Sql, Bindings) of
        [[Value]] when is_integer(Value) ->
            run_integer_queries(Connection, Rest, Check + Value);
        {error, Code} ->
            to_sqlight_error(Connection, {app_request_query_failed, Sql, Code});
        Rows ->
            generic_sqlight_error({app_request_wrong_result, Sql, Rows})
    end.

to_sqlight_error(Connection, Code) when is_integer(Code) ->
    #{errmsg := Message, error_offset := Offset} = esqlite3:error_info(Connection),
    {error, {sqlight_error, sqlight:error_code_from_int(Code), Message, Offset}};
to_sqlight_error(_Connection, Reason) ->
    generic_sqlight_error(Reason).

generic_sqlight_error(Reason) ->
    Message = unicode:characters_to_binary(io_lib:format("prepared benchmark failed: ~p", [Reason])),
    {error, {sqlight_error, generic_error, Message, -1}}.

start_heartbeat(PeriodMicros) ->
    spawn(fun() ->
        heartbeat_loop(
            PeriodMicros,
            erlang:monotonic_time(microsecond),
            0,
            0,
            0
        )
    end).

stop_heartbeat(Pid) ->
    Ref = erlang:monitor(process, Pid),
    Pid ! {stop, self(), Ref},
    receive
        {heartbeat, Ref, Count, MaxDelay, AvgDelay} ->
            erlang:demonitor(Ref, [flush]),
            {Count, MaxDelay, AvgDelay};
        {'DOWN', Ref, process, Pid, Reason} ->
            erlang:error({heartbeat_down, Reason})
    end.

heartbeat_loop(PeriodMicros, LastWake, Count, TotalDelay, MaxDelay) ->
    receive
        {stop, From, Ref} ->
            AvgDelay = average_delay(TotalDelay, Count),
            From ! {heartbeat, Ref, Count, MaxDelay, AvgDelay}
    after heartbeat_timeout_millisecond(PeriodMicros) ->
        Now = erlang:monotonic_time(microsecond),
        Delay = max(0, Now - LastWake - PeriodMicros),
        heartbeat_loop(
            PeriodMicros,
            Now,
            Count + 1,
            TotalDelay + Delay,
            max(MaxDelay, Delay)
        )
    end.

heartbeat_timeout_millisecond(PeriodMicros) when PeriodMicros =< 1000 ->
    1;
heartbeat_timeout_millisecond(PeriodMicros) ->
    (PeriodMicros + 999) div 1000.

average_delay(_TotalDelay, 0) ->
    0;
average_delay(TotalDelay, Count) ->
    TotalDelay div Count.

start_read_file_probe() ->
    Parent = self(),
    Ref = make_ref(),
    {Pid, MonitorRef} = spawn_monitor(fun() ->
        read_file_probe_init(Parent, Ref)
    end),
    receive
        {read_file_probe_ready, Ref, Pid} ->
            erlang:demonitor(MonitorRef, [flush]),
            Pid;
        {'DOWN', MonitorRef, process, Pid, Reason} ->
            erlang:error({read_file_probe_down, Reason})
    end.

stop_read_file_probe(Pid) ->
    Ref = erlang:monitor(process, Pid),
    Pid ! {stop, self(), Ref},
    receive
        {read_file_probe, Ref, Attempts, Failures, MaxLatency, AvgLatency, BytesRead, LastFailureCode} ->
            erlang:demonitor(Ref, [flush]),
            {Attempts, Failures, MaxLatency, AvgLatency, BytesRead, LastFailureCode};
        {'DOWN', Ref, process, Pid, Reason} ->
            erlang:error({read_file_probe_down, Reason})
    end.

read_file_probe_init(Parent, Ref) ->
    ok = ensure_read_file_probe_file(?READ_FILE_PROBE_PATH),
    Parent ! {read_file_probe_ready, Ref, self()},
    read_file_probe_loop(?READ_FILE_PROBE_PATH, 0, 0, 0, 0, 0, 0).

read_file_probe_loop(Path, Attempts, Failures, TotalLatency, MaxLatency, BytesRead, LastFailureCode) ->
    receive
        {stop, From, Ref} ->
            AvgLatency = average_delay(TotalLatency, Attempts),
            From ! {read_file_probe, Ref, Attempts, Failures, MaxLatency, AvgLatency, BytesRead, LastFailureCode}
    after 0 ->
        {AttemptFailures, Latency, AttemptBytes, FailureCode} = read_file_probe_attempt(Path),
        NextFailureCode = case FailureCode of
            0 -> LastFailureCode;
            _ -> FailureCode
        end,
        read_file_probe_loop(
            Path,
            Attempts + 1,
            Failures + AttemptFailures,
            TotalLatency + Latency,
            max(MaxLatency, Latency),
            BytesRead + AttemptBytes,
            NextFailureCode
        )
    end.

read_file_probe_attempt(Path) ->
    Start = erlang:monotonic_time(microsecond),
    ReadResult = file:read_file(Path),
    Latency = erlang:monotonic_time(microsecond) - Start,
    case ReadResult of
        {ok, Bytes} ->
            {0, Latency, byte_size(Bytes), 0};
        {error, Reason} ->
            {1, Latency, 0, read_file_failure_code(Reason)}
    end.

read_file_failure_code(enoent) -> 2;
read_file_failure_code(eacces) -> 13;
read_file_failure_code(_Reason) -> 8.

start_sendfile_probe() ->
    Parent = self(),
    Ref = make_ref(),
    {Pid, MonitorRef} = spawn_monitor(fun() ->
        sendfile_probe_init(Parent, Ref)
    end),
    receive
        {sendfile_probe_ready, Ref, Pid} ->
            erlang:demonitor(MonitorRef, [flush]),
            Pid;
        {'DOWN', MonitorRef, process, Pid, Reason} ->
            erlang:error({sendfile_probe_down, Reason})
    end.

stop_sendfile_probe(Pid) ->
    Ref = erlang:monitor(process, Pid),
    Pid ! {stop, self(), Ref},
    receive
        {sendfile_probe, Ref, Attempts, Failures, MaxLatency, AvgLatency, BytesSent, LastFailureCode} ->
            erlang:demonitor(Ref, [flush]),
            {Attempts, Failures, MaxLatency, AvgLatency, BytesSent, LastFailureCode};
        {'DOWN', Ref, process, Pid, Reason} ->
            erlang:error({sendfile_probe_down, Reason})
    end.

sendfile_probe_init(Parent, Ref) ->
    ok = ensure_sendfile_probe_file(?SENDFILE_PROBE_PATH),
    {ok, ListenSocket} = gen_tcp:listen(0, [
        binary,
        {packet, raw},
        {active, false},
        {ip, {127, 0, 0, 1}},
        {reuseaddr, true}
    ]),
    {ok, Port} = inet:port(ListenSocket),
    {ok, ClientSocket} = gen_tcp:connect(
        {127, 0, 0, 1},
        Port,
        [binary, {packet, raw}, {active, false}, {nodelay, true}],
        1000
    ),
    {ok, ServerSocket} = gen_tcp:accept(ListenSocket, 1000),
    gen_tcp:close(ListenSocket),
    DrainPid = spawn(fun() ->
        receive
            {sendfile_probe_socket, Socket} ->
                drain_sendfile_socket(Socket)
        end
    end),
    ok = gen_tcp:controlling_process(ServerSocket, DrainPid),
    DrainPid ! {sendfile_probe_socket, ServerSocket},
    Parent ! {sendfile_probe_ready, Ref, self()},
    sendfile_probe_loop(?SENDFILE_PROBE_PATH, ClientSocket, DrainPid, 0, 0, 0, 0, 0, 0).

sendfile_probe_loop(Path, ClientSocket, DrainPid, Attempts, Failures, TotalLatency, MaxLatency, BytesSent, LastFailureCode) ->
    receive
        {stop, From, Ref} ->
            gen_tcp:close(ClientSocket),
            exit(DrainPid, kill),
            AvgLatency = average_delay(TotalLatency, Attempts),
            From ! {sendfile_probe, Ref, Attempts, Failures, MaxLatency, AvgLatency, BytesSent, LastFailureCode}
    after 0 ->
        {AttemptFailures, Latency, AttemptBytes, FailureCode} = sendfile_probe_attempt(Path, ClientSocket),
        NextFailureCode = case FailureCode of
            0 -> LastFailureCode;
            _ -> FailureCode
        end,
        sendfile_probe_loop(
            Path,
            ClientSocket,
            DrainPid,
            Attempts + 1,
            Failures + AttemptFailures,
            TotalLatency + Latency,
            max(MaxLatency, Latency),
            BytesSent + AttemptBytes,
            NextFailureCode
        )
    end.

sendfile_probe_attempt(Path, Socket) ->
    Start = erlang:monotonic_time(microsecond),
    SendResult = file:sendfile(Path, Socket),
    Latency = erlang:monotonic_time(microsecond) - Start,
    case SendResult of
        {ok, BytesSent} ->
            {0, Latency, BytesSent, 0};
        {error, Reason} ->
            {1, Latency, 0, sendfile_failure_code(Reason)}
    end.

sendfile_failure_code(timeout) -> 6;
sendfile_failure_code(closed) -> 11;
sendfile_failure_code(enotconn) -> 13;
sendfile_failure_code(_Reason) -> 8.

drain_sendfile_socket(Socket) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Data} ->
            _ = byte_size(Data),
            drain_sendfile_socket(Socket);
        {error, closed} ->
            ok;
        {error, _Reason} ->
            ok
    end.

ensure_sendfile_probe_file(Path) ->
    case file:read_file_info(Path) of
        {ok, #file_info{size = ?SENDFILE_PROBE_SIZE}} ->
            ok;
        {ok, _Info} ->
            write_sendfile_probe_file(Path);
        {error, enoent} ->
            write_sendfile_probe_file(Path);
        {error, Reason} ->
            {error, Reason}
    end.

write_sendfile_probe_file(Path) ->
    Chunk = <<"0123456789abcdef">>,
    file:write_file(Path, binary:copy(Chunk, ?SENDFILE_PROBE_SIZE div byte_size(Chunk))).

ensure_read_file_probe_file(Path) ->
    case file:read_file_info(Path) of
        {ok, #file_info{size = ?READ_FILE_PROBE_SIZE}} ->
            ok;
        {ok, _Info} ->
            write_read_file_probe_file(Path);
        {error, enoent} ->
            write_read_file_probe_file(Path);
        {error, Reason} ->
            {error, Reason}
    end.

write_read_file_probe_file(Path) ->
    Chunk = <<"0123456789abcdef">>,
    file:write_file(Path, binary:copy(Chunk, ?READ_FILE_PROBE_SIZE div byte_size(Chunk))).
