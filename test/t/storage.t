# vi:filetype=perl

use lib 'lib';
use Test::Nginx::LWP;

plan tests => $Test::Nginx::LWP::RepeatEach * 2 * blocks();

#no_diff;

run_tests();

__DATA__

=== TEST 1: set only
--- config
    location /memc {
        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;
        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /memc?key=foo&cmd=set&val=blah
--- response_body eval
"STORED\r\n"
--- error_code: 201



=== TEST 2: set and get
--- config
    location /main {
        echo 'set foo blah';
        echo_location '/memc?key=foo&cmd=set&val=blah';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;
        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"set foo blah
STORED\r
get foo
blah"



=== TEST 3: set and get empty values
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'set foo blah';
        echo_location '/memc?key=foo&cmd=set&val=';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;
        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"flush all
OK\r
set foo blah
STORED\r
get foo
"



=== TEST 4: add
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'add foo blah';
        echo_location '/memc?key=foo&cmd=add&val=added';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"flush all
status: 200
OK\r
add foo blah
status: 201
STORED\r
get foo
status: 200
added"



=== TEST 5: set using POST
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'set foo';
        echo_subrequest POST '/memc?key=foo&cmd=set';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        #set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
POST /main
hello, world
--- response_body eval
"flush all
status: 200
OK\r
set foo
status: 201
STORED\r
get foo
status: 200
hello, world"



=== TEST 6: default REST interface when no $memc_cmd is set
--- config
    location /main {
        echo 'set foo FOO';
        echo_subrequest PUT '/memc?key=foo' -b FOO;

        echo 'get foo';
        echo_subrequest GET '/memc?key=foo';
        echo;

        echo 'set foo BAR';
        echo_subrequest PUT '/memc?key=foo' -b BAR;

        echo 'get foo';
        echo_subrequest GET '/memc?key=foo';
        echo;
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_key $arg_key;
        #set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
GET /main
--- response_body eval
"set foo FOO
status: 201
STORED\r
get foo
status: 200
FOO
set foo BAR
status: 201
STORED\r
get foo
status: 200
BAR
"



=== TEST 7: default REST interface when no $memc_cmd is set (read client req body)
--- config
    location /main {
        echo 'set foo <client req body>';
        echo_subrequest PUT '/memc?key=foo';

        echo 'get foo';
        echo_subrequest GET '/memc?key=foo';
        echo;

        echo 'set foo BAR';
        echo_subrequest PUT '/memc?key=foo' -b BAR;

        echo 'get foo';
        echo_subrequest GET '/memc?key=foo';
        echo;
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_key $arg_key;
        #set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
POST /main
rock
--- response_body eval
"set foo <client req body>
status: 201
STORED\r
get foo
status: 200
rock
set foo BAR
status: 201
STORED\r
get foo
status: 200
BAR
"



=== TEST 8: default REST interface when no $memc_cmd is set (read client req body)
--- config
    location /main {
        echo 'set foo <client req body>';
        echo_subrequest PUT '/memc?key=foo';

        echo 'get foo';
        echo_subrequest GET '/memc?key=foo';
        echo;

        echo 'add foo BAR';
        echo_subrequest POST '/memc?key=foo' -b BAR;

        echo 'get foo';
        echo_subrequest GET '/memc?key=foo';
        echo;
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_key $arg_key;
        #set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
POST /main
howdy
--- response_body eval
"set foo <client req body>
status: 201
STORED\r
get foo
status: 200
howdy
add foo BAR
status: 200
NOT_STORED\r
get foo
status: 200
howdy
"



=== TEST 9: test replace (stored) (without sleep)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';
        #echo_sleep 0.001;

        echo 'add foo blah';
        echo_location '/memc?key=foo&cmd=add&val=added';

        echo 'replace foo bah';
        echo_location '/memc?key=foo&cmd=replace&val=bah';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"flush all
status: 200
OK\r
add foo blah
status: 201
STORED\r
replace foo bah
status: 201
STORED\r
get foo
status: 200
bah"



=== TEST 10: test replace (stored) (with sleep)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';
        echo_sleep 0.001;

        echo 'add foo blah';
        echo_location '/memc?key=foo&cmd=add&val=added';
        #echo_sleep 0.001;

        echo 'replace foo bah';
        echo_location '/memc?key=foo&cmd=replace&val=bah';
        #echo_sleep 0.001;

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"flush all
status: 200
OK\r
add foo blah
status: 201
STORED\r
replace foo bah
status: 201
STORED\r
get foo
status: 200
bah"
--- skip_nginx: 2: < 0.8.11



=== TEST 11: test replace (not stored)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'replace foo bah';
        echo_location '/memc?key=foo&cmd=replace&val=bah';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body_like
flush all
status: 200
OK\r
replace foo bah
status: 200
NOT_STORED\r
get foo
status: 404.*?404 Not Found.*$



=== TEST 12: test append (stored)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'add foo hello';
        echo_location '/memc?key=foo&cmd=add&val=hello';

        echo 'append foo ,world';
        echo_location '/memc?key=foo&cmd=append&val=,world';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"flush all
status: 200
OK\r
add foo hello
status: 201
STORED\r
append foo ,world
status: 201
STORED\r
get foo
status: 200
hello,world"



=== TEST 13: test append (not stored)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'append foo ,world';
        echo_location '/memc?key=foo&cmd=append&val=,world';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body_like
flush all
status: 200
OK\r
append foo ,world
status: 200
NOT_STORED\r
get foo
status: 404.*?404 Not Found.*$



=== TEST 14: test prepend (stored)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'add foo hello';
        echo_location '/memc?key=foo&cmd=add&val=hello';

        echo 'prepend foo world,';
        echo_location '/memc?key=foo&cmd=prepend&val=world,';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body eval
"flush all
status: 200
OK\r
add foo hello
status: 201
STORED\r
prepend foo world,
status: 201
STORED\r
get foo
status: 200
world,hello"



=== TEST 15: test prepend (not stored)
--- config
    location /main {
        echo 'flush all';
        echo_location '/memc?cmd=flush_all';

        echo 'prepend foo world,';
        echo_location '/memc?key=foo&cmd=prepend&val=world,';

        echo 'get foo';
        echo_location '/memc?key=foo&cmd=get';
    }
    location /memc {
        echo_before_body "status: $echo_response_status";

        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        set $memc_value $arg_val;

        memc_pass 127.0.0.1:11984;
    }
--- request
    GET /main
--- response_body_like
flush all
status: 200
OK\r
prepend foo world,
status: 200
NOT_STORED\r
get foo
status: 404.*?404 Not Found.*$



=== TEST 16: set and get big value
--- config
    location /big {
        client_body_buffer_size 1k;
        client_max_body_size 100k;

        echo 'set big';
        echo_subrequest POST '/memc?key=big&cmd=set';

        echo 'get big';
        echo_location '/memc?key=big&cmd=get';
    }
    location /memc {
        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        memc_pass 127.0.0.1:11984;
    }
--- request eval
"POST /big\n" .
 'a' x (1024 * 90) . 'efg'

--- response_body eval
"set big
STORED\r
get big
" . 'a' x (1024 * 90) . 'efg'



=== TEST 17: set and get too big values
--- config
    location /big {
        client_body_buffer_size 1k;
        client_max_body_size 100k;

        echo 'set big';
        echo_subrequest POST '/memc?key=big&cmd=set';

        echo 'get big';
        echo_location '/memc?key=big&cmd=get';
    }
    location /memc {
        set $memc_cmd $arg_cmd;
        set $memc_key $arg_key;
        memc_pass 127.0.0.1:11984;
    }
--- request eval
"POST /big\n" .
 'a' x (1024 * 100) . 'efg'

--- response_body_like: 413 Request Entity Too Large
--- error_code: 413



