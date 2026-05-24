package config

import (
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Port              string
	EnableDebugRoutes bool

	AllowedOrigins []string
	TrustedProxies []string

	GlobalRateLimitRPS   float64
	GlobalRateLimitBurst int
	PerIPRateLimitRPS    float64
	PerIPRateLimitBurst  int

	MaxPage int

	CacheEnabled    bool
	CacheTTL        time.Duration
	CacheMaxEntries int

	AsyncEnabled    bool
	AsyncWorkers    int
	AsyncQueueSize  int
	AsyncJobTimeout time.Duration
	AsyncJobTTL     time.Duration

	MetricsEnabled bool

	ScrapeTimeoutSeconds int
	ScrapeRetryCount     int
	ScrapeRetryBaseDelay time.Duration
	ScrapeMinDelay       time.Duration
	ScrapeMaxDelay       time.Duration
	ScrapeDomainRPS      float64
	ScrapeDomainBurst    int
	ScrapeFailThreshold  int
	ScrapeCooldown       time.Duration
	ScrapeRespectRobots  bool

	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	IdleTimeout     time.Duration
	ShutdownTimeout time.Duration
}

func Load() *Config {
	return &Config{
		Port:              getEnv("PORT", "8080"),
		EnableDebugRoutes: getEnvBool("ENABLE_DEBUG_ROUTES", false),
		AllowedOrigins:    getEnvCSV("CORS_ALLOWED_ORIGINS", []string{"*"}),
		TrustedProxies: getEnvCSV("TRUSTED_PROXIES", []string{
			"127.0.0.1/32",
			"::1/128",
			"10.0.0.0/8",
			"172.16.0.0/12",
			"192.168.0.0/16",
		}),

		GlobalRateLimitRPS:   getEnvFloat64("GLOBAL_RATE_LIMIT_RPS", 100),
		GlobalRateLimitBurst: getEnvInt("GLOBAL_RATE_LIMIT_BURST", 200),
		PerIPRateLimitRPS:    getEnvFloat64("PER_IP_RATE_LIMIT_RPS", 20),
		PerIPRateLimitBurst:  getEnvInt("PER_IP_RATE_LIMIT_BURST", 40),

		MaxPage: getEnvInt("MAX_PAGE", 100),

		CacheEnabled:    getEnvBool("CACHE_ENABLED", true),
		CacheTTL:        getEnvDuration("CACHE_TTL", 2*time.Minute),
		CacheMaxEntries: getEnvInt("CACHE_MAX_ENTRIES", 5000),

		AsyncEnabled:    getEnvBool("ASYNC_ENABLED", false),
		AsyncWorkers:    getEnvInt("ASYNC_WORKERS", 4),
		AsyncQueueSize:  getEnvInt("ASYNC_QUEUE_SIZE", 512),
		AsyncJobTimeout: getEnvDuration("ASYNC_JOB_TIMEOUT", 25*time.Second),
		AsyncJobTTL:     getEnvDuration("ASYNC_JOB_TTL", 15*time.Minute),

		MetricsEnabled: getEnvBool("METRICS_ENABLED", true),

		ScrapeTimeoutSeconds: getEnvInt("SCRAPE_TIMEOUT_SECONDS", 15),
		ScrapeRetryCount:     getEnvInt("SCRAPE_RETRY_COUNT", 1),
		ScrapeRetryBaseDelay: getEnvDuration("SCRAPE_RETRY_BASE_DELAY", 250*time.Millisecond),
		ScrapeMinDelay:       getEnvDuration("SCRAPE_MIN_DELAY", 120*time.Millisecond),
		ScrapeMaxDelay:       getEnvDuration("SCRAPE_MAX_DELAY", 350*time.Millisecond),
		ScrapeDomainRPS:      getEnvFloat64("SCRAPE_DOMAIN_RPS", 4),
		ScrapeDomainBurst:    getEnvInt("SCRAPE_DOMAIN_BURST", 8),
		ScrapeFailThreshold:  getEnvInt("SCRAPE_FAIL_THRESHOLD", 6),
		ScrapeCooldown:       getEnvDuration("SCRAPE_COOLDOWN", 2*time.Minute),
		ScrapeRespectRobots:  getEnvBool("SCRAPE_RESPECT_ROBOTS", false),

		ReadTimeout:     getEnvDuration("READ_TIMEOUT", 15*time.Second),
		WriteTimeout:    getEnvDuration("WRITE_TIMEOUT", 120*time.Second),
		IdleTimeout:     getEnvDuration("IDLE_TIMEOUT", 90*time.Second),
		ShutdownTimeout: getEnvDuration("SHUTDOWN_TIMEOUT", 20*time.Second),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	value := os.Getenv(key)
	switch value {
	case "1", "true", "TRUE", "yes", "YES", "on", "ON":
		return true
	case "0", "false", "FALSE", "no", "NO", "off", "OFF":
		return false
	default:
		return defaultValue
	}
}

func getEnvInt(key string, defaultValue int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return defaultValue
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return parsed
}

func getEnvFloat64(key string, defaultValue float64) float64 {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return defaultValue
	}
	parsed, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return defaultValue
	}
	return parsed
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return defaultValue
	}
	parsed, err := time.ParseDuration(value)
	if err != nil {
		return defaultValue
	}
	return parsed
}

func getEnvCSV(key string, defaultValue []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return defaultValue
	}
	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		item := strings.TrimSpace(part)
		if item != "" {
			result = append(result, item)
		}
	}
	if len(result) == 0 {
		return defaultValue
	}
	return result
}
