package madarascans

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://madarascans.com"

type MadaraScans struct{}

func New() *MadaraScans {
	return &MadaraScans{}
}

func (m *MadaraScans) ID() string         { return "madarascans" }
func (m *MadaraScans) Name() string       { return "MadaraScans" }
func (m *MadaraScans) GetBaseURL() string { return baseURL }
func (m *MadaraScans) GetType() string    { return "manga" }

func (m *MadaraScans) Popular(page int) ([]scrapers.MediaItem, error) {
	url := baseURL + "/"
	if page > 1 {
		url = fmt.Sprintf("%s/page/%d/", baseURL, page)
	}
	return fetchCards(url)
}

func (m *MadaraScans) Latest(page int) ([]scrapers.MediaItem, error) {
	url := baseURL + "/"
	if page > 1 {
		url = fmt.Sprintf("%s/page/%d/", baseURL, page)
	}
	return fetchCards(url)
}

func (m *MadaraScans) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/?s=%s", baseURL, q)
	if page > 1 {
		url = fmt.Sprintf("%s/?s=%s&paged=%d", baseURL, q, page)
	}
	return fetchCards(url)
}

func (m *MadaraScans) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/series/%s/", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	info := &scrapers.MediaInfo{
		ID:     id,
		Source: "madarascans",
		Type:   "manga",
	}

	// Title — multiple fallbacks
	info.Title = scrapers.CleanText(doc.Find(".post-title h1, .series-title, .lh-series-title, h1.entry-title").First().Text())
	if info.Title == "" {
		info.Title = scrapers.CleanText(doc.Find("h1").First().Text())
	}

	// Cover
	info.CoverURL = doc.Find(".summary_image img, .lh-cover img, .series-cover img, .legend-cover img").First().AttrOr("src", "")
	if info.CoverURL == "" {
		info.CoverURL = doc.Find(".summary_image img").First().AttrOr("data-src", "")
	}

	// Description — stored in #manga-story
	info.Description = scrapers.CleanText(doc.Find("#manga-story, .summary__content, .description-summary").First().Text())

	// Meta fields
	doc.Find(".post-content_item").Each(func(_ int, s *goquery.Selection) {
		label := strings.ToLower(scrapers.CleanText(s.Find(".summary-heading h5").Text()))
		value := scrapers.CleanText(s.Find(".summary-content").Text())
		switch {
		case strings.Contains(label, "author"):
			info.Author = value
		case strings.Contains(label, "artist"):
			info.Artist = value
		case strings.Contains(label, "status"):
			info.Status = value
		case strings.Contains(label, "alt"):
			if value != "" {
				info.AltTitles = strings.Split(value, ";")
				for i := range info.AltTitles {
					info.AltTitles[i] = strings.TrimSpace(info.AltTitles[i])
				}
			}
		}
	})

	// Status from ribbon if not found above
	if info.Status == "" {
		info.Status = scrapers.CleanText(doc.Find(".legend-ribbon").First().Text())
	}

	// Genres
	doc.Find(".genres-content a, .series-genres a, .lh-genres a").Each(func(_ int, s *goquery.Selection) {
		g := scrapers.CleanText(s.Text())
		if g != "" {
			info.Genres = append(info.Genres, g)
		}
	})

	return info, nil
}

func (m *MadaraScans) GetChapters(id string) ([]scrapers.Chapter, error) {
	url := fmt.Sprintf("%s/series/%s/", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var chapters []scrapers.Chapter
	extractChapter := func(href, title, date string) {
		absURL := scrapers.AbsoluteURL(baseURL, href)
		chapterPath := strings.TrimPrefix(strings.TrimRight(absURL, "/"), baseURL+"/")
		if chapterPath == "" {
			return
		}
		chapters = append(chapters, scrapers.Chapter{
			ID:        chapterPath,
			Title:     title,
			URL:       absURL,
			UpdatedAt: date,
		})
	}

	// Madarascans uses div.ch-item with a.ch-main-anchor inside
	doc.Find("#chapters-list-container .ch-item").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a.ch-main-anchor").First()
		href, _ := a.Attr("href")
		if href == "" {
			return
		}

		title := scrapers.CleanText(a.Find(".ch-num").Text())
		date := scrapers.CleanText(a.Find(".ch-date").Text())
		extractChapter(href, title, date)
	})

	// Fallback selector used by other Madara theme variants
	if len(chapters) == 0 {
		doc.Find(".wp-manga-chapter").Each(func(_ int, s *goquery.Selection) {
			a := s.Find("a").First()
			href, _ := a.Attr("href")
			if href == "" {
				return
			}
			title := scrapers.CleanText(a.Text())
			date := scrapers.CleanText(s.Find(".chapter-release-date").Text())
			extractChapter(href, title, date)
		})
	}

	if len(chapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}

	return chapters, nil
}

func (m *MadaraScans) GetPages(chapterID string) ([]string, error) {
	chapterID = strings.TrimPrefix(chapterID, "/")

	candidates := make([]string, 0, 3)
	if strings.HasPrefix(chapterID, "http://") || strings.HasPrefix(chapterID, "https://") {
		candidates = append(candidates, chapterID)
	} else {
		candidates = append(candidates, scrapers.AbsoluteURL(baseURL, chapterID))
		if !strings.HasPrefix(chapterID, "series/") {
			candidates = append(candidates, fmt.Sprintf("%s/series/%s", baseURL, chapterID))
		}
		candidates = append(candidates, fmt.Sprintf("%s/%s", baseURL, chapterID))
	}

	var (
		body    []byte
		err     error
		lastErr error
	)
	for _, candidate := range candidates {
		body, err = scrapers.FetchHTML(candidate, baseURL)
		if err == nil {
			lastErr = nil
			break
		}
		lastErr = err
	}
	if lastErr != nil {
		return nil, lastErr
	}

	// Try ts_reader.run() JSON first
	re := regexp.MustCompile(`ts_reader\.run\((\{.*?\})\)`)
	match := re.FindSubmatch(body)
	if match != nil {
		var data struct {
			Sources []struct {
				Images []string `json:"images"`
			} `json:"sources"`
		}
		if err := json.Unmarshal(match[1], &data); err == nil {
			if len(data.Sources) > 0 && len(data.Sources[0].Images) > 0 {
				return data.Sources[0].Images, nil
			}
		}
	}

	// Fallback: .page-break img
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var pages []string
	doc.Find(".page-break img, .reading-content img").Each(func(_ int, s *goquery.Selection) {
		src := strings.TrimSpace(s.AttrOr("data-src", ""))
		if src == "" {
			src = strings.TrimSpace(s.AttrOr("src", ""))
		}
		if src != "" && !strings.Contains(src, "placeholder") {
			pages = append(pages, src)
		}
	})

	if len(pages) == 0 {
		return nil, fmt.Errorf("no pages found for chapter: %s", chapterID)
	}

	return pages, nil
}

// ── helpers ────────────────────────────────────────────────────────────

func fetchCards(url string) ([]scrapers.MediaItem, error) {
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var items []scrapers.MediaItem

	doc.Find("article.legend-card").Each(func(_ int, s *goquery.Selection) {
		poster := s.Find("a.legend-poster").First()
		href, _ := poster.Attr("href")
		if href == "" {
			return
		}

		cover := poster.Find("img.legend-img").AttrOr("src", "")
		title := scrapers.CleanText(s.Find(".legend-title a").First().Text())
		if title == "" {
			title, _ = poster.Find("img").First().Attr("alt")
		}
		latestChap := scrapers.CleanText(s.Find(".legend-ch-link .ch-txt").First().Text())
		slug := scrapers.ExtractLastSegment(strings.TrimRight(href, "/"))

		if slug != "" && title != "" {
			items = append(items, scrapers.MediaItem{
				ID:         slug,
				Title:      scrapers.CleanText(title),
				CoverURL:   cover,
				URL:        href,
				Source:     "madarascans",
				Type:       "manga",
				LatestChap: latestChap,
			})
		}
	})

	return items, nil
}
