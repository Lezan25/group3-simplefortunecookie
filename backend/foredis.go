package main

import (
	"fmt"
	"github.com/gomodule/redigo/redis"
	"log"
	"os"
	"sync"
	"time"
)

var dbPool *redis.Pool
var usingRedis = false

func init() {
	// Check if REDIS_DNS environment variable is set
	if os.Getenv("REDIS_DNS") == "" {
		fmt.Println("redis config not set")
		return
	}

	addr := getEnv("REDIS_DNS", "localhost:6379")

	pool := &redis.Pool{
		MaxIdle:     10,
		MaxActive:   50,
		IdleTimeout: 240 * time.Second,
		Dial: func() (redis.Conn, error) {
			return redis.Dial("tcp", addr)
		},
	}

	var err error
	for i := 0; i < 5; i++ {
		conn := pool.Get()
		_, err = conn.Do("PING")
		if closeErr := conn.Close(); closeErr != nil {
			log.Println("redis: failed to close connection:", closeErr)
		}
		if err == nil {
			usingRedis = true
			break
		}
		log.Printf("Attempt %d: redis connection failed: %s", i+1, err)
		time.Sleep(2 * time.Second)
	}

	if !usingRedis {
		log.Println("Failed to connect to redis after 5 attempts")
		return
	}

	dbPool = pool

	conn := dbPool.Get()
	defer func() {
		if err := conn.Close(); err != nil {
			log.Println("redis: failed to close connection:", err)
		}
	}()

	resKeys, err := redis.Values(conn.Do("hkeys", "fortunes"))
	if err != nil {
		fmt.Println("redis hkeys failed", err.Error())
		return
	}

	datastoreDefault = datastore{m: map[string]fortune{}, RWMutex: &sync.RWMutex{}}
	fmt.Printf("*** loading redis fortunes:\n")
	for _, key := range resKeys {
		val, err := conn.Do("hget", "fortunes", key)
		if err != nil {
			fmt.Println("redis hget failed", err.Error())
		} else {
			idx := string(key.([]byte))
			msg := string(val.([]byte))
			datastoreDefault.m[idx] = fortune{ID: idx, Message: msg}
			fmt.Printf("%s => %s\n", key, val)
		}
	}
}
