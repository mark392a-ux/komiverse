package wetriedtls

import (
	"encoding/json"
	"fmt"
	"net/url"
	"regexp"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://wetriedtls.com"
const apiURL = "https://api.wetriedtls.com"

type WeTried struct{}

func New() *WeTried { return &WeTried{} }

func (w *WeTried) ID() string         { return "wetriedtls" }
func (w *WeTried) Name() string       { return "WeTried TLS" }
func (w *WeTried) GetBaseURL() string { return baseURL }
func (w *WeTried) GetType() string    { return "novel" }

// ── API types ──────────────────────────────────────────────────────────

type queryResp struct {
	Meta struct {
		Total       int `json:"total"`
		LastPage    int `json:"last_page"`
		CurrentPage int `json:"current_page"`
	} `json:"meta"`
	Data []seriesItem `json:"data"`
}

type seriesItem struct {
	ID           int    `json:"id"`
	Title        string `json:"title"`
	SeriesSlug   string `json:"series_slug"`
	Thumbnail    string `json:"thumbnail"`
	Status       string `json:"status"`
	Description  string `json:"description"`
	Author       string `json:"author"`
	FreeChapters []struct {
		ChapterName string `json:"chapter_name"`
		ChapterSlug string `json:"chapter_slug"`
	} `json:"free_chapters"`
	Meta struct {
		ChaptersCount string `json:"chapters_count"`
	} `json:"meta"`
}

type seriesDetail struct {
	ID          int    `json:"id"`
	Title       string `json:"title"`
	SeriesSlug  string `json:"series_slug"`
	Thumbnail   string `json:"thumbnail"`
	Status      string `json:"status"`
	Description string `json:"description"`
	Author      string `json:"author"`
	Tags        []struct {
		Name string `json:"name"`
	} `json:"tags"`
	Seasons []struct {
		ID         int    `json:"id"`
		SeasonName string `json:"season_name"`
		Index      int    `json:"index"`
	} `json:"seasons"`
	Meta struct {
		ChaptersCount string `json:"chapters_count"`
	} `json:"meta"`
}

type chaptersResp struct {
	Data []struct {
		ID           int    `json:"id"`
		ChapterName  string `json:"chapter_name"`
		ChapterTitle string `json:"chapter_title"`
		ChapterSlug  string `json:"chapter_slug"`
		CreatedAt    string `json:"created_at"`
		Index        string `json:"index"`
	} `json:"data"`
	Meta struct {
		LastPage int `json:"last_page"`
	} `json:"meta"`
}

// ── HTTP helper ────────────────────────────────────────────────────────

func fetchAPI(endpoint string) ([]byte, error) {
	return scrapers.FetchAPI(endpoint, baseURL)
}

// stripHTML removes HTML tags from a string
func stripHTML(s string) string {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(s))
	if err != nil {
		return s
	}
	return strings.TrimSpace(doc.Text())
}

// ── Browse ─────────────────────────────────────────────────────────────

func (w *WeTried) Popular(page int) ([]scrapers.MediaItem, error) {
	u := fmt.Sprintf("%s/query?adult=true&query_string=&orderBy=rating&page=%d&series_type=Novel", apiURL, page)
	return fetchList(u)
}

func (w *WeTried) Latest(page int) ([]scrapers.MediaItem, error) {
	u := fmt.Sprintf("%s/query?adult=true&query_string=&orderBy=created_at&page=%d&series_type=Novel", apiURL, page)
	return fetchList(u)
}

func (w *WeTried) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := url.QueryEscape(query)
	u := fmt.Sprintf("%s/query?adult=true&query_string=%s&page=%d&series_type=Novel", apiURL, q, page)
	return fetchList(u)
}

func fetchList(endpoint string) ([]scrapers.MediaItem, error) {
	body, err := fetchAPI(endpoint)
	if err != nil {
		return nil, err
	}
	var resp queryResp
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
			Source:     "wetriedtls",
			Type:       "novel",
			LatestChap: latestChap,
		})
	}
	return items, nil
}

// ── Info ───────────────────────────────────────────────────────────────

func (w *WeTried) GetInfo(id string) (*scrapers.MediaInfo, error) {
	body, err := fetchAPI(fmt.Sprintf("%s/series/%s", apiURL, id))
	if err != nil {
		return nil, err
	}
	var s seriesDetail
	if err := json.Unmarshal(body, &s); err != nil {
		return nil, err
	}

	var genres []string
	for _, t := range s.Tags {
		if t.Name != "" {
			genres = append(genres, t.Name)
		}
	}

	return &scrapers.MediaInfo{
		ID:          id,
		Title:       s.Title,
		CoverURL:    s.Thumbnail,
		Description: stripHTML(s.Description),
		Author:      s.Author,
		Status:      s.Status,
		Genres:      genres,
		Type:        "novel",
		Source:      "wetriedtls",
	}, nil
}

// ── Chapters ───────────────────────────────────────────────────────────

func (w *WeTried) GetChapters(id string) ([]scrapers.Chapter, error) {
	// id = "series-slug" — first get numeric series ID
	body, err := fetchAPI(fmt.Sprintf("%s/series/%s", apiURL, id))
	if err != nil {
		return nil, err
	}
	var detail seriesDetail
	if err := json.Unmarshal(body, &detail); err != nil {
		return nil, err
	}
	seriesID := detail.ID

	// Fetch all chapter pages using /chapters/{id}
	var allChapters []scrapers.Chapter
	page := 1
	for {
		u := fmt.Sprintf("%s/chapters/%d?page=%d&perPage=1000&query=&order=asc", apiURL, seriesID, page)
		body, err := fetchAPI(u)
		if err != nil {
			return nil, err
		}
		var resp chaptersResp
		if err := json.Unmarshal(body, &resp); err != nil {
			return nil, fmt.Errorf("chapters parse error: %w", err)
		}
		for _, ch := range resp.Data {
			title := ch.ChapterName
			if ch.ChapterTitle != "" && ch.ChapterTitle != "Spoiler" {
				title = ch.ChapterName + " - " + ch.ChapterTitle
			}
			chID := fmt.Sprintf("%s/%s", id, ch.ChapterSlug)
			chURL := fmt.Sprintf("%s/series/%s/%s", baseURL, id, ch.ChapterSlug)
			allChapters = append(allChapters, scrapers.Chapter{
				ID:        chID,
				Title:     title,
				URL:       chURL,
				UpdatedAt: ch.CreatedAt,
			})
		}
		if page >= resp.Meta.LastPage || len(resp.Data) == 0 {
			break
		}
		page++
	}

	// Also fetch paid chapters and append
	paidBody, err := fetchAPI(fmt.Sprintf("%s/chapters/%d/paid?query=&order=asc", apiURL, seriesID))
	if err == nil {
		var paidResp chaptersResp
		if json.Unmarshal(paidBody, &paidResp) == nil {
			for _, ch := range paidResp.Data {
				title := ch.ChapterName + " [Locked]"
				if ch.ChapterTitle != "" && ch.ChapterTitle != "Spoiler" {
					title = ch.ChapterName + " - " + ch.ChapterTitle + " [Locked]"
				}
				chID := fmt.Sprintf("%s/%s", id, ch.ChapterSlug)
				chURL := fmt.Sprintf("%s/series/%s/%s", baseURL, id, ch.ChapterSlug)
				allChapters = append(allChapters, scrapers.Chapter{
					ID:        chID,
					Title:     title,
					URL:       chURL,
					UpdatedAt: ch.CreatedAt,
				})
			}
		}
	}

	if len(allChapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}
	return allChapters, nil
}

// ── Pages ──────────────────────────────────────────────────────────────

var nextFRe = regexp.MustCompile(`self\.__next_f\.push\(\[1,"(.*?)"\]\)`)

func (w *WeTried) GetPages(chapterID string) ([]string, error) {
	// chapterID = "{seriesSlug}/{chapterSlug}"
	pageURL := fmt.Sprintf("%s/series/%s", baseURL, chapterID)

	body, err := scrapers.FetchHTML(pageURL, baseURL)
	if err != nil {
		return nil, err
	}

	// Extract content from self.__next_f.push([1,"..."])
	// The chapter HTML is JSON-encoded inside this push call
	matches := nextFRe.FindAllSubmatch(body, -1)
	var content string
	for _, m := range matches {
		if len(m) < 2 {
			continue
		}
		raw := string(m[1])
		// JSON unescape the string
		var decoded string
		if err := json.Unmarshal([]byte(string([]byte{34})+raw+string([]byte{34})), &decoded); err != nil {
			decoded = unescapeUnicode(raw)
		}
		if strings.Contains(decoded, "<p dir") {
			start := strings.Index(decoded, "<p dir")
			if start != -1 {
				content = decoded[start:]
				break
			}
		}
	}

	if strings.TrimSpace(content) == "" {
		return nil, fmt.Errorf("no content found for chapter: %s", chapterID)
	}
	return []string{content}, nil
}

// unescapeUnicode converts \uXXXX sequences to actual characters
func unescapeUnicode(s string) string {
	var result strings.Builder
	i := 0
	for i < len(s) {
		if i+5 < len(s) && s[i] == '\\' && s[i+1] == 'u' {
			var r rune
			fmt.Sscanf(s[i+2:i+6], "%04x", &r)
			result.WriteRune(r)
			i += 6
		} else {
			result.WriteByte(s[i])
			i++
		}
	}
	return result.String()
}
