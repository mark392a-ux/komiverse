package jobs

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"sync"
	"time"
)

type Status string

const (
	StatusQueued    Status = "queued"
	StatusRunning   Status = "running"
	StatusCompleted Status = "completed"
	StatusFailed    Status = "failed"
)

type Job struct {
	ID        string      `json:"id"`
	Type      string      `json:"type"`
	Status    Status      `json:"status"`
	Error     string      `json:"error,omitempty"`
	Result    interface{} `json:"result,omitempty"`
	CreatedAt time.Time   `json:"created_at"`
	UpdatedAt time.Time   `json:"updated_at"`
}

type execFn func(context.Context) (interface{}, error)

type queuedJob struct {
	id   string
	exec execFn
}

type Manager struct {
	mu sync.RWMutex

	jobs map[string]*Job

	queue      chan queuedJob
	workers    int
	jobTimeout time.Duration
	jobTTL     time.Duration
}

func NewManager(workers, queueSize int, jobTimeout, jobTTL time.Duration) *Manager {
	if workers <= 0 {
		workers = 1
	}
	if queueSize <= 0 {
		queueSize = 128
	}
	if jobTimeout <= 0 {
		jobTimeout = 20 * time.Second
	}
	if jobTTL <= 0 {
		jobTTL = 10 * time.Minute
	}

	m := &Manager{
		jobs:       make(map[string]*Job),
		queue:      make(chan queuedJob, queueSize),
		workers:    workers,
		jobTimeout: jobTimeout,
		jobTTL:     jobTTL,
	}

	for i := 0; i < workers; i++ {
		go m.workerLoop()
	}
	go m.cleanupLoop()

	return m
}

func (m *Manager) Submit(jobType string, fn execFn) (*Job, error) {
	if fn == nil {
		return nil, errors.New("job function is required")
	}

	id, err := randomID()
	if err != nil {
		return nil, err
	}

	now := time.Now()
	job := &Job{
		ID:        id,
		Type:      jobType,
		Status:    StatusQueued,
		CreatedAt: now,
		UpdatedAt: now,
	}

	m.mu.Lock()
	m.jobs[id] = job
	m.mu.Unlock()

	select {
	case m.queue <- queuedJob{id: id, exec: fn}:
		return m.Get(id)
	default:
		m.failJob(id, "queue is full")
		return m.Get(id)
	}
}

func (m *Manager) Get(id string) (*Job, error) {
	m.mu.RLock()
	job, ok := m.jobs[id]
	m.mu.RUnlock()
	if !ok {
		return nil, errors.New("job not found")
	}
	copy := *job
	return &copy, nil
}

func (m *Manager) workerLoop() {
	for q := range m.queue {
		m.updateStatus(q.id, StatusRunning, "")

		ctx, cancel := context.WithTimeout(context.Background(), m.jobTimeout)
		result, err := q.exec(ctx)
		cancel()

		if err != nil {
			m.failJob(q.id, err.Error())
			continue
		}
		m.completeJob(q.id, result)
	}
}

func (m *Manager) updateStatus(id string, status Status, errMessage string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	job, ok := m.jobs[id]
	if !ok {
		return
	}
	job.Status = status
	job.Error = errMessage
	job.UpdatedAt = time.Now()
}

func (m *Manager) failJob(id, errMessage string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	job, ok := m.jobs[id]
	if !ok {
		return
	}
	job.Status = StatusFailed
	job.Error = errMessage
	job.UpdatedAt = time.Now()
}

func (m *Manager) completeJob(id string, result interface{}) {
	m.mu.Lock()
	defer m.mu.Unlock()
	job, ok := m.jobs[id]
	if !ok {
		return
	}
	job.Status = StatusCompleted
	job.Result = result
	job.UpdatedAt = time.Now()
}

func (m *Manager) cleanupLoop() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		cutoff := time.Now().Add(-m.jobTTL)
		m.mu.Lock()
		for id, job := range m.jobs {
			if (job.Status == StatusCompleted || job.Status == StatusFailed) && job.UpdatedAt.Before(cutoff) {
				delete(m.jobs, id)
			}
		}
		m.mu.Unlock()
	}
}

func randomID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	return hex.EncodeToString(b[:]), nil
}
