package mangageko

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://www.mgeko.cc"

type MangaGeko struct{}

func New() *MangaGeko {
	return &MangaGeko{}
}

func (m *MangaGeko) ID() string         { return "mangageko" }
func (m *MangaGeko) Name() string       { return "MangaGeko" }
func (m *MangaGeko) GetBaseURL() string { return baseURL }
func (m *MangaGeko) GetType() string    { return "manga" }

func (m *MangaGeko) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/jumbo/manga/?hot=true&page=%d", baseURL, page)
	return fetchCards(url)
}

func (m *MangaGeko) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/jumbo/manga/?page=%d", baseURL, page)
	return fetchCards(url)
}

func (m *MangaGeko) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/search/?search=%s&page=%d", baseURL, q, page)
	return fetchCards(url)
}

func (m *MangaGeko) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/manga/%s/", baseURL, id)
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
		Source: "mangageko",
		Type:   "manga",
	}

	// Title
	info.Title = scrapers.CleanText(doc.Find("h1.novel-title").First().Text())
	if info.Title == "" {
		info.Title = scrapers.CleanText(doc.Find("h1").First().Text())
	}

	// Alt titles
	altTitle := scrapers.CleanText(doc.Find("h2.alternative-title").First().Text())
	if altTitle != "" {
		info.AltTitles = []string{altTitle}
	}

	// Cover — lazy loaded via data-src
	info.CoverURL = doc.Find("figure.cover img.lazy").First().AttrOr("data-src", "")
	if info.CoverURL == "" {
		info.CoverURL = doc.Find(".cover-wrap img, .novel-cover img").First().AttrOr("src", "")
	}
	if info.CoverURL == "" {
		info.CoverURL = doc.Find("img").First().AttrOr("src", "")
	}

	// Description
	info.Description = scrapers.CleanText(doc.Find(".summary .content, #novel-desc, .description").First().Text())

	// Author
	doc.Find(".author a span[itemprop='author']").Each(func(_ int, s *goquery.Selection) {
		v := scrapers.CleanText(s.Text())
		if v != "" && info.Author == "" {
			info.Author = v
		}
	})
	if info.Author == "" {
		info.Author = scrapers.CleanText(doc.Find(".author").First().Text())
	}

	// Status, Type from header stats
	doc.Find(".header-stats span").Each(func(_ int, s *goquery.Selection) {
		label := strings.ToLower(scrapers.CleanText(s.Find("small").Text()))
		value := scrapers.CleanText(s.Find("strong").Text())
		switch label {
		case "status":
			info.Status = value
		case "type":
			info.Type = value
		}
	})

	// Genres
	doc.Find(".categories a, .tag").Each(func(_ int, s *goquery.Selection) {
		g := scrapers.CleanText(s.Text())
		if g != "" {
			info.Genres = append(info.Genres, g)
		}
	})

	return info, nil
}

func (m *MangaGeko) GetChapters(id string) ([]scrapers.Chapter, error) {
	url := fmt.Sprintf("%s/manga/%s/", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var chapters []scrapers.Chapter

	doc.Find("ul.chapter-list li, #chapter-list li").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a").First()
		href, _ := a.Attr("href")
		if href == "" {
			return
		}

		title := scrapers.CleanText(a.Find(".chapter-title").Text())
		if title == "" {
			title = scrapers.CleanText(a.Text())
		}
		date := scrapers.CleanText(s.Find(".chapter-update, time").First().Text())
		slug := scrapers.ExtractLastSegment(href)

		// Build absolute URL
		if !strings.HasPrefix(href, "http") {
			href = baseURL + href
		}

		chapters = append(chapters, scrapers.Chapter{
			ID:        slug,
			Title:     title,
			URL:       href,
			UpdatedAt: date,
		})
	})

	if len(chapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}

	return chapters, nil
}

func (m *MangaGeko) GetPages(chapterID string) ([]string, error) {
	// Reader URL: /reader/en/manga-name-chapter-X-eng-li/
	chapterID = strings.TrimPrefix(chapterID, "/")
	url := fmt.Sprintf("%s/reader/en/%s/", baseURL, chapterID)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	// Try ts_reader.run() JSON first (same pattern as ThunderScans)
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

	// Fallback: scrape img tags from reader div
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var pages []string
	doc.Find("#chapter-reader img, .chapter-reader img, .reader-content img, .reading-content img").Each(func(_ int, s *goquery.Selection) {
		src := s.AttrOr("src", "")
		if src == "" {
			src = s.AttrOr("data-src", "")
		}
		if src == "" {
			src = s.AttrOr("data-lazy-src", "")
		}
		if src != "" && !strings.Contains(src, "placeholder") {
			if !strings.HasPrefix(src, "http") {
				src = baseURL + src
			}
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

	doc.Find("li.novel-item").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a").First()
		href, _ := a.Attr("href")

		title := scrapers.CleanText(s.Find("h4.novel-title").First().Text())
		if title == "" {
			title, _ = s.Find("img").First().Attr("alt")
		}

		// Cover is lazy loaded via data-src
		cover := s.Find("img.lazy").First().AttrOr("data-src", "")
		if cover == "" {
			cover = s.Find("img").First().AttrOr("src", "")
		}

		id := scrapers.ExtractLastSegment(href)

		if id != "" && title != "" {
			// Make absolute URL
			if !strings.HasPrefix(href, "http") {
				href = baseURL + href
			}
			items = append(items, scrapers.MediaItem{
				ID:       id,
				Title:    scrapers.CleanText(title),
				CoverURL: cover,
				URL:      href,
				Source:   "mangageko",
				Type:     "manga",
			})
		}
	})

	return items, nil
}
