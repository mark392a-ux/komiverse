package omegascans

import (
	"encoding/json"
	"fmt"
	"strings"

	"HUANG/backend/internal/scrapers"
)

const (
	baseURL = "https://omegascans.org"
	apiURL  = "https://api.omegascans.org"
)

type OmegaScans struct{}

func New() *OmegaScans {
	return &OmegaScans{}
}

func (o *OmegaScans) ID() string         { return "omegascans" }
func (o *OmegaScans) Name() string       { return "OmegaScans" }
func (o *OmegaScans) GetBaseURL() string { return baseURL }
func (o *OmegaScans) GetType() string    { return "manga" }

// ── API types ──────────────────────────────────────────────────────────

type queryResponse struct {
	Data []seriesSummary `json:"data"`
}

type seriesSummary struct {
	ID               int    `json:"id"`
	Title            string `json:"title"`
	SeriesSlug       string `json:"series_slug"`
	Thumbnail        string `json:"thumbnail"`
	TotalViews       int    `json:"total_views"`
	Status           string `json:"status"`
	SeriesType       string `json:"series_type"`
	AlternativeNames string `json:"alternative_names"`
	FreeChapters     []struct {
		ChapterName string `json:"chapter_name"`
		ChapterSlug string `json:"chapter_slug"`
	} `json:"free_chapters"`
}

type seriesDetail struct {
	ID               int    `json:"id"`
	Title            string `json:"title"`
	SeriesSlug       string `json:"series_slug"`
	Thumbnail        string `json:"thumbnail"`
	Description      string `json:"description"`
	Status           string `json:"status"`
	SeriesType       string `json:"series_type"`
	AlternativeNames string `json:"alternative_names"`
	Author           string `json:"author"`
	Studio           string `json:"studio"`
	ReleaseYear      string `json:"release_year"`
	Tags             []struct {
		Name string `json:"name"`
	} `json:"tags"`
}

type chapterItem struct {
	ID           int    `json:"id"`
	ChapterName  string `json:"chapter_name"`
	ChapterTitle string `json:"chapter_title"`
	ChapterSlug  string `json:"chapter_slug"`
	Price        int    `json:"price"`
	CreatedAt    string `json:"created_at"`
}

type chapterDetail struct {
	Chapter struct {
		ChapterData struct {
			Images []string `json:"images"`
		} `json:"chapter_data"`
	} `json:"chapter"`
}

// ── fetch helper ───────────────────────────────────────────────────────

func fetch(url string) ([]byte, error) {
	return scrapers.FetchAPI(url, baseURL)
}

// ── interface methods ──────────────────────────────────────────────────

func (o *OmegaScans) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/query?page=%d&perPage=20&order=desc&orderBy=total_views&adult=true", apiURL, page)
	return fetchSeriesList(url)
}

func (o *OmegaScans) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/query?page=%d&perPage=20&order=desc&orderBy=created_at&adult=true", apiURL, page)
	return fetchSeriesList(url)
}

func (o *OmegaScans) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/query?page=%d&perPage=20&query_string=%s&adult=true", apiURL, page, q)
	return fetchSeriesList(url)
}

func (o *OmegaScans) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/series/%s", apiURL, id)
	body, err := fetch(url)
	if err != nil {
		return nil, err
	}

	var s seriesDetail
	if err := json.Unmarshal(body, &s); err != nil {
		return nil, err
	}

	if s.Title == "" {
		return nil, fmt.Errorf("series not found: %s", id)
	}

	info := &scrapers.MediaInfo{
		ID:          id,
		Title:       s.Title,
		CoverURL:    s.Thumbnail,
		Description: s.Description,
		Author:      s.Author,
		Status:      s.Status,
		Type:        "manga",
		Source:      "omegascans",
	}

	if s.AlternativeNames != "" {
		info.AltTitles = []string{s.AlternativeNames}
	}

	for _, tag := range s.Tags {
		if tag.Name != "" {
			info.Genres = append(info.Genres, tag.Name)
		}
	}

	return info, nil
}

func (o *OmegaScans) GetChapters(id string) ([]scrapers.Chapter, error) {
	url := fmt.Sprintf("%s/chapter/all/%s", apiURL, id)
	body, err := fetch(url)
	if err != nil {
		return nil, err
	}

	var items []chapterItem
	if err := json.Unmarshal(body, &items); err != nil {
		return nil, err
	}

	if len(items) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}

	chapters := make([]scrapers.Chapter, 0, len(items))
	for _, ch := range items {
		title := ch.ChapterName
		if ch.ChapterTitle != "" {
			title = ch.ChapterName + " - " + ch.ChapterTitle
		}
		// ID format: {series-slug}/{chapter-slug} so GetPages can use it
		chapters = append(chapters, scrapers.Chapter{
			ID:        id + "/" + ch.ChapterSlug,
			Title:     title,
			URL:       fmt.Sprintf("%s/series/%s/%s", baseURL, id, ch.ChapterSlug),
			UpdatedAt: ch.CreatedAt,
		})
	}

	return chapters, nil
}

func (o *OmegaScans) GetPages(chapterID string) ([]string, error) {
	// chapterID = "{series-slug}/{chapter-slug}"
	chapterID = strings.TrimPrefix(chapterID, "/")
	url := fmt.Sprintf("%s/chapter/%s", apiURL, chapterID)
	body, err := fetch(url)
	if err != nil {
		return nil, err
	}

	var detail chapterDetail
	if err := json.Unmarshal(body, &detail); err != nil {
		return nil, err
	}

	images := detail.Chapter.ChapterData.Images
	if len(images) == 0 {
		return nil, fmt.Errorf("no pages found for chapter: %s", chapterID)
	}

	return images, nil
}

// ── helpers ────────────────────────────────────────────────────────────

func fetchSeriesList(url string) ([]scrapers.MediaItem, error) {
	body, err := fetch(url)
	if err != nil {
		return nil, err
	}

	var resp queryResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, err
	}

	items := make([]scrapers.MediaItem, 0, len(resp.Data))
	for _, s := range resp.Data {
		latestChap := ""
		if len(s.FreeChapters) > 0 {
			latestChap = s.FreeChapters[0].ChapterName
		}

		items = append(items, scrapers.MediaItem{
			ID:         s.SeriesSlug,
			Title:      s.Title,
			CoverURL:   s.Thumbnail,
			URL:        fmt.Sprintf("%s/series/%s", baseURL, s.SeriesSlug),
			Source:     "omegascans",
			Type:       "manga",
			LatestChap: latestChap,
		})
	}

	return items, nil
}
