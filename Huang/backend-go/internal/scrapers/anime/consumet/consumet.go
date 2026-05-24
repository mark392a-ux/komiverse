package consumet

import (
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"

	"HUANG/backend/internal/scrapers"
)

const defaultConsumetBase = "http://localhost:3000/anime"

var consumetBase = resolveConsumetBase()

func resolveConsumetBase() string {
	// Allow Docker/local overrides while keeping localhost as the fallback.
	base := strings.TrimSpace(os.Getenv("CONSUMET_BASE_URL"))
	if base == "" {
		base = defaultConsumetBase
	}
	return strings.TrimRight(base, "/")
}

// Provider represents a single anime provider via Consumet
type Provider struct {
	id       string
	name     string
	provider string // consumet route name e.g. "animepahe"
	siteURL  string
}

func NewAnimePahe() *Provider {
	return &Provider{
		id:       "animepahe",
		name:     "AnimePahe",
		provider: "animepahe",
		siteURL:  "https://animepahe.si",
	}
}

func (p *Provider) ID() string         { return p.id }
func (p *Provider) Name() string       { return p.name }
func (p *Provider) GetBaseURL() string { return p.siteURL }
func (p *Provider) GetType() string    { return "anime" }

// ── types ──────────────────────────────────────────────────────────────

type searchResp struct {
	Results []struct {
		ID    string `json:"id"`
		Title string `json:"title"`
		Image string `json:"image"`
	} `json:"results"`
}

type infoResp struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	Image       string   `json:"image"`
	Cover       string   `json:"cover"`
	Description string   `json:"description"`
	Genres      []string `json:"genres"`
	Status      string   `json:"status"`
	TotalPages  int      `json:"totalPages"`
	Episodes    []struct {
		ID     string `json:"id"`
		Number int    `json:"number"`
		Title  string `json:"title"`
		URL    string `json:"url"`
	} `json:"episodes"`
}

type watchResp struct {
	Headers map[string]string `json:"headers"`
	Sources []struct {
		URL     string `json:"url"`
		IsM3U8  bool   `json:"isM3U8"`
		Quality string `json:"quality"`
		IsDub   bool   `json:"isDub"`
	} `json:"sources"`
	Download []struct {
		URL     string `json:"url"`
		Quality string `json:"quality"`
	} `json:"download"`
}

type recentResp struct {
	Results []struct {
		ID            string `json:"id"`
		Title         string `json:"title"`
		EpisodeID     string `json:"episodeId"`
		EpisodeImage  string `json:"episodeImage"`
		EpisodeNumber int    `json:"episodeNumber"`
	} `json:"results"`
}

// ── helpers ────────────────────────────────────────────────────────────

func (p *Provider) url(path string) string {
	return fmt.Sprintf("%s/%s%s", consumetBase, p.provider, path)
}

func fetch(endpoint string) ([]byte, error) {
	body, err := scrapers.FetchAPI(endpoint, consumetBase)
	if err != nil {
		return nil, fmt.Errorf("consumet unreachable (is it running on port 3000?): %w", err)
	}
	return body, nil
}

// ── interface ──────────────────────────────────────────────────────────

func (p *Provider) Popular(page int) ([]scrapers.MediaItem, error) {
	body, err := fetch(p.url(fmt.Sprintf("/recent-episodes?page=%d", page)))
	if err != nil {
		return nil, err
	}
	var resp recentResp
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, err
	}
	seen := make(map[string]bool)
	var items []scrapers.MediaItem
	for _, r := range resp.Results {
		if seen[r.ID] {
			continue
		}
		seen[r.ID] = true
		items = append(items, scrapers.MediaItem{
			ID:         r.ID,
			Title:      r.Title,
			CoverURL:   r.EpisodeImage,
			URL:        fmt.Sprintf("%s/anime/%s", p.siteURL, r.ID),
			Source:     p.id,
			Type:       "anime",
			LatestChap: fmt.Sprintf("Episode %d", r.EpisodeNumber),
		})
	}
	return items, nil
}

func (p *Provider) Latest(page int) ([]scrapers.MediaItem, error) {
	return p.Popular(page)
}

func (p *Provider) Search(query string, page int) ([]scrapers.MediaItem, error) {
	body, err := fetch(p.url("/" + url.QueryEscape(query)))
	if err != nil {
		return nil, err
	}
	var resp searchResp
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, err
	}
	var items []scrapers.MediaItem
	for _, r := range resp.Results {
		items = append(items, scrapers.MediaItem{
			ID:       r.ID,
			Title:    r.Title,
			CoverURL: r.Image,
			URL:      fmt.Sprintf("%s/anime/%s", p.siteURL, r.ID),
			Source:   p.id,
			Type:     "anime",
		})
	}
	return items, nil
}

func (p *Provider) GetInfo(id string) (*scrapers.MediaInfo, error) {
	body, err := fetch(p.url(fmt.Sprintf("/info/%s?episodePage=1", id)))
	if err != nil {
		return nil, err
	}
	var resp infoResp
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, err
	}
	cover := resp.Cover
	if cover == "" {
		cover = resp.Image
	}
	return &scrapers.MediaInfo{
		ID:          id,
		Title:       resp.Title,
		CoverURL:    cover,
		Description: resp.Description,
		Status:      resp.Status,
		Genres:      resp.Genres,
		Type:        "anime",
		Source:      p.id,
	}, nil
}

func (p *Provider) GetChapters(id string) ([]scrapers.Chapter, error) {
	var all []scrapers.Chapter
	for page := 1; ; page++ {
		body, err := fetch(p.url(fmt.Sprintf("/info/%s?episodePage=%d", id, page)))
		if err != nil {
			return nil, err
		}
		var resp infoResp
		if err := json.Unmarshal(body, &resp); err != nil {
			return nil, err
		}
		for _, ep := range resp.Episodes {
			title := fmt.Sprintf("Episode %d", ep.Number)
			if ep.Title != "" {
				title = fmt.Sprintf("Episode %d - %s", ep.Number, ep.Title)
			}
			all = append(all, scrapers.Chapter{ID: ep.ID, Title: title, URL: ep.URL})
		}
		if page >= resp.TotalPages || len(resp.Episodes) == 0 {
			break
		}
	}
	if len(all) == 0 {
		return nil, fmt.Errorf("no episodes found for: %s", id)
	}
	return all, nil
}

func (p *Provider) GetPages(episodeID string) ([]string, error) {
	body, err := fetch(p.url("/watch?episodeId=" + url.QueryEscape(episodeID)))
	if err != nil {
		return nil, err
	}
	var resp watchResp
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, err
	}
	if len(resp.Sources) == 0 {
		return nil, fmt.Errorf("no stream sources for: %s", episodeID)
	}

	// Pick best quality: 1080p sub > 720p sub > first
	best := resp.Sources[0].URL
	for _, s := range resp.Sources {
		if !s.IsDub && strings.Contains(s.Quality, "1080") {
			best = s.URL
			break
		}
	}
	if best == resp.Sources[0].URL {
		for _, s := range resp.Sources {
			if !s.IsDub && strings.Contains(s.Quality, "720") {
				best = s.URL
				break
			}
		}
	}

	type streamOut struct {
		Best     string            `json:"best"`
		Sources  interface{}       `json:"sources"`
		Headers  map[string]string `json:"headers"`
		Download interface{}       `json:"download"`
	}
	j, _ := json.Marshal(streamOut{best, resp.Sources, resp.Headers, resp.Download})
	return []string{best, string(j)}, nil
}
