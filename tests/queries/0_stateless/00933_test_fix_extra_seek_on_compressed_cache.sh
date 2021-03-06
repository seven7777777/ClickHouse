#!/usr/bin/env bash

CURDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CURDIR"/../shell_config.sh


$CLICKHOUSE_CLIENT --query="DROP TABLE IF EXISTS small_table"

$CLICKHOUSE_CLIENT --query="CREATE TABLE small_table (a UInt64 default 0, n UInt64) ENGINE = MergeTree() PARTITION BY tuple() ORDER BY (a) SETTINGS min_bytes_for_wide_part = 0;"

$CLICKHOUSE_CLIENT --query="INSERT INTO small_table (n) SELECT * from system.numbers limit 100000;"
$CLICKHOUSE_CLIENT --query="OPTIMIZE TABLE small_table FINAL;"

cached_query="SELECT count() FROM small_table where n > 0;"

$CLICKHOUSE_CLIENT --use_uncompressed_cache=1 --query="$cached_query" &> /dev/null

$CLICKHOUSE_CLIENT --use_uncompressed_cache=1 --query_id="test-query-uncompressed-cache" --query="$cached_query" &> /dev/null

$CLICKHOUSE_CLIENT --query="SYSTEM FLUSH LOGS"

$CLICKHOUSE_CLIENT --query="SELECT ProfileEvents.Values[indexOf(ProfileEvents.Names, 'Seek')], ProfileEvents.Values[indexOf(ProfileEvents.Names, 'ReadCompressedBytes')], ProfileEvents.Values[indexOf(ProfileEvents.Names, 'UncompressedCacheHits')] AS hit FROM system.query_log WHERE (query_id = 'test-query-uncompressed-cache') AND current_database = currentDatabase() AND (type = 2) AND event_date >= yesterday() ORDER BY event_time DESC LIMIT 1"

$CLICKHOUSE_CLIENT --query="DROP TABLE IF EXISTS small_table"

