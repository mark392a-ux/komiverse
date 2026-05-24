package registry

import "HUANG/backend/internal/scrapers"

// Registry holds all registered scrapers
// When your app asks for "mangafire", this finds and returns it
type Registry struct {
	sources map[string]scrapers.Source
}

// New creates an empty registry
func New() *Registry {
	return &Registry{
		sources: make(map[string]scrapers.Source),
	}
}

// Register adds a scraper to the registry
func (r *Registry) Register(s scrapers.Source) {
	r.sources[s.ID()] = s
}

// Get finds a scraper by ID
func (r *Registry) Get(id string) (scrapers.Source, bool) {
	s, ok := r.sources[id]
	return s, ok
}

// All returns every registered scraper
func (r *Registry) All() []scrapers.Source {
	list := make([]scrapers.Source, 0, len(r.sources))
	for _, s := range r.sources {
		list = append(list, s)
	}
	return list
}

// AllByType returns scrapers filtered by type ("manga", "anime", "novel")
func (r *Registry) AllByType(t string) []scrapers.Source {
	var list []scrapers.Source
	for _, s := range r.sources {
		if s.GetType() == t {
			list = append(list, s)
		}
	}
	return list
}
