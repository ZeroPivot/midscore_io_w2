require "redis"
require_relative "lib/partitioned_array/lib/line_db"

$redis_conn = Redis.new(host: 'localhost', port: 6379, db: 2)
$redis_conn.set("db", LineDB.new) 
$r2 = LineDB.new
#p $r2["sim"]
line_db = $redis_conn.get("db")
p line_db.class
p $r2.class
