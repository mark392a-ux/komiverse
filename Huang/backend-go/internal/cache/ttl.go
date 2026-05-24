package cache

import (
	"sync"
	"time"
)

type entry struct {
	value     interface{}
	expiresAt time.Time
	createdAt time.Time
}

// TTLCache is a thread-safe in-memory cache with per-entry expiration.
type TTLCache struct {
	mu          sync.RWMutex
	items       map[string]entry
	defaultTTL  time.Duration
	maxEntries  int
	cleanupTick time.Duration
}

func NewTTLCache(defaultTTL time.Duration, maxEntries int) *TTLCache {
	if defaultTTL <= 0 {
		defaultTTL = time.Minute
	}
	if maxEntries <= 0 {
		maxEntries = 1000
	}
	c := &TTLCache{
		items:       make(map[string]entry),
		defaultTTL:  defaultTTL,
		maxEntries:  maxEntries,
		cleanupTick: time.Minute,
	}
	go c.cleanupLoop()
	return c
}

func (c *TTLCache) Get(key string) (interface{}, bool) {
	now := time.Now()

	c.mu.RLock()
	item, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		return nil, false
	}
	if now.After(item.expiresAt) {
		c.Delete(key)
		return nil, false
	}
	return item.value, true
}

func (c *TTLCache) GetStale(key string) (interface{}, bool) {
	c.mu.RLock()
	item, ok := c.items[key]
	c.mu.RUnlock()
	if !ok {
		return nil, false
	}
	return item.value, true
}

func (c *TTLCache) Set(key string, value interface{}) {
	c.SetWithTTL(key, value, c.defaultTTL)
}

func (c *TTLCache) SetWithTTL(key string, value interface{}, ttl time.Duration) {
	if ttl <= 0 {
		ttl = c.defaultTTL
	}
	now := time.Now()

	c.mu.Lock()
	defer c.mu.Unlock()

	if len(c.items) >= c.maxEntries {
		c.evictOneLocked(now)
	}

	c.items[key] = entry{
		value:     value,
		createdAt: now,
		expiresAt: now.Add(ttl),
	}
}

func (c *TTLCache) Delete(key string) {
	c.mu.Lock()
	delete(c.items, key)
	c.mu.Unlock()
}

func (c *TTLCache) cleanupLoop() {
	ticker := time.NewTicker(c.cleanupTick)
	defer ticker.Stop()
	for range ticker.C {
		c.purgeExpired()
	}
}

func (c *TTLCache) purgeExpired() {
	now := time.Now()
	c.mu.Lock()
	for key, item := range c.items {
		if now.After(item.expiresAt) {
			delete(c.items, key)
		}
	}
	c.mu.Unlock()
}

func (c *TTLCache) evictOneLocked(now time.Time) {
	// Prefer removing expired entries.
	for key, item := range c.items {
		if now.After(item.expiresAt) {
			delete(c.items, key)
			return
		}
	}

	// Otherwise remove oldest item.
	var oldestKey string
	var oldestAt time.Time
	first := true
	for key, item := range c.items {
		if first || item.createdAt.Before(oldestAt) {
			first = false
			oldestKey = key
			oldestAt = item.createdAt
		}
	}
	if oldestKey != "" {
		delete(c.items, oldestKey)
	}
}
