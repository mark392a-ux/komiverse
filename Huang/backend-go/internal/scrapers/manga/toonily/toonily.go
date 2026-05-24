package toonily

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://toonily.com"

type Toonily struct{}

func New() *Toonily {
	return &Toonily{}
}

func (t *Toonily) ID() string         { return "toonily" }
func (t *Toonily) Name() string       { return "Toonily" }
func (t *Toonily) GetBaseURL() string { return baseURL }
func (t *Toonily) GetType() string    { return "manga" }

func (t *Toonily) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/serie/?m_orderby=trending&page=%d", baseURL, page)
	return fetchCards(url, "toonily")
}

func (t *Toonily) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/serie/?m_orderby=latest&page=%d", baseURL, page)
	return fetchCards(url, "toonily")
}

func (t *Toonily) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/?s=%s&post_type=wp-manga&page=%d", baseURL, q, page)
	return fetchCards(url, "toonily")
}

func (t *Toonily) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/serie/%s/", baseURL, id)
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
		Source: "toonily",
		Type:   "manga",
	}

	info.Title = scrapers.CleanText(doc.Find(".post-title h1").First().Text())
	if info.Title == "" {
		info.Title = scrapers.CleanText(doc.Find("h1").First().Text())
	}

	info.CoverURL = doc.Find(".summary_image img").First().AttrOr("data-src", "")
	if info.CoverURL == "" {
		info.CoverURL = doc.Find(".summary_image img").First().AttrOr("src", "")
	}

	info.Description = scrapers.CleanText(doc.Find(".summary__content").First().Text())

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

	doc.Find(".genres-content a").Each(func(_ int, s *goquery.Selection) {
		g := scrapers.CleanText(s.Text())
		if g != "" {
			info.Genres = append(info.Genres, g)
		}
	})

	return info, nil
}

func (t *Toonily) GetChapters(id string) ([]scrapers.Chapter, error) {
	url := fmt.Sprintf("%s/serie/%s/", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var chapters []scrapers.Chapter

	// Standard Madara chapter list
	doc.Find(".wp-manga-chapter").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a").First()
		href, _ := a.Attr("href")
		if href == "" {
			return
		}
		absURL := scrapers.AbsoluteURL(baseURL, href)
		title := scrapers.CleanText(a.Text())
		date := scrapers.CleanText(s.Find(".chapter-release-date").Text())
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
	})

	if len(chapters) > 0 {
		return chapters, nil
	}

	// Fallback: AJAX via admin-ajax.php
	postID, _ := doc.Find("#manga-chapters-holder").Attr("data-id")
	if postID == "" {
		postID, _ = doc.Find("[data-id]").First().Attr("data-id")
	}

	if postID != "" {
		ajaxURL := fmt.Sprintf("%s/wp-admin/admin-ajax.php", baseURL)
		ajaxBody := fmt.Sprintf("action=manga_get_chapters&manga=%s", postID)
		ajaxResp, err := scrapers.FetchAjaxPost(ajaxURL, baseURL, ajaxBody)
		if err == nil {
			ajaxDoc, err := goquery.NewDocumentFromReader(strings.NewReader(string(ajaxResp)))
			if err == nil {
				ajaxDoc.Find(".wp-manga-chapter").Each(func(_ int, s *goquery.Selection) {
					a := s.Find("a").First()
					href, _ := a.Attr("href")
					if href == "" {
						return
					}
					absURL := scrapers.AbsoluteURL(baseURL, href)
					title := scrapers.CleanText(a.Text())
					date := scrapers.CleanText(s.Find(".chapter-release-date").Text())
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
				})
			}
		}
	}

	if len(chapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}

	return chapters, nil
}

func (t *Toonily) GetPages(chapterID string) ([]string, error) {
	chapterID = strings.TrimPrefix(chapterID, "/")

	candidates := make([]string, 0, 2)
	if strings.HasPrefix(chapterID, "http://") || strings.HasPrefix(chapterID, "https://") {
		candidates = append(candidates, chapterID)
	} else {
		candidates = append(candidates, scrapers.AbsoluteURL(baseURL, chapterID))
		if !strings.Contains(chapterID, "/") {
			candidates = append(candidates, fmt.Sprintf("%s/%s/", baseURL, chapterID))
		}
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
		if src != "" &&
			!strings.Contains(src, "placeholder") &&
			!strings.Contains(src, "/wp-content/assets/999.png") {
			pages = append(pages, src)
		}
	})

	if len(pages) == 0 {
		return nil, fmt.Errorf("no pages found for chapter: %s", chapterID)
	}

	return pages, nil
}

// ── helpers ────────────────────────────────────────────────────────────

func fetchCards(url, source string) ([]scrapers.MediaItem, error) {
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var items []scrapers.MediaItem

	doc.Find(".page-item-detail").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a").First()
		href, _ := a.Attr("href")
		if href == "" {
			return
		}

		title := scrapers.CleanText(s.Find(".post-title").Text())
		if title == "" {
			title, _ = s.Find("img").First().Attr("alt")
		}

		cover := s.Find("img").First().AttrOr("data-src", "")
		if cover == "" {
			cover = s.Find("img").First().AttrOr("src", "")
		}

		latestChap := scrapers.CleanText(s.Find(".chapter").First().Text())
		id := scrapers.ExtractLastSegment(strings.TrimRight(href, "/"))

		if id != "" && title != "" {
			items = append(items, scrapers.MediaItem{
				ID:         id,
				Title:      scrapers.CleanText(title),
				CoverURL:   cover,
				URL:        href,
				Source:     source,
				Type:       "manga",
				LatestChap: latestChap,
			})
		}
	})

	return items, nil
}
