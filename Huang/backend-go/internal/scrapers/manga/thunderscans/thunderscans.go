package thunderscans

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://en-thunderscans.com"

type ThunderScans struct{}

func New() *ThunderScans {
	return &ThunderScans{}
}

func (t *ThunderScans) ID() string         { return "thunderscans" }
func (t *ThunderScans) Name() string       { return "ThunderScans" }
func (t *ThunderScans) GetBaseURL() string { return baseURL }
func (t *ThunderScans) GetType() string    { return "manga" }

func (t *ThunderScans) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/comics/?order=popular&page=%d", baseURL, page)
	return fetchCards(url)
}

func (t *ThunderScans) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/comics/?order=update&page=%d", baseURL, page)
	return fetchCards(url)
}

func (t *ThunderScans) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/?s=%s&page=%d", baseURL, q, page)
	return fetchCards(url)
}

func (t *ThunderScans) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/comics/%s/", baseURL, id)
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
		Source: "thunderscans",
		Type:   "manga",
	}

	info.Title = scrapers.CleanText(doc.Find("h1.entry-title").First().Text())
	info.CoverURL = doc.Find(".first-half img").First().AttrOr("src", "")
	info.Description = scrapers.CleanText(doc.Find(".summary .wd-full").Text())

	doc.Find(".imptdt").Each(func(_ int, s *goquery.Selection) {
		label := strings.ToLower(strings.TrimSpace(s.Find("h1").Text()))
		value := strings.TrimSpace(s.Find("i").First().Text())
		switch label {
		case "status":
			info.Status = value
		case "type":
			info.Type = value
		case "author":
			info.Author = value
		case "artist":
			info.Artist = value
		}
	})

	doc.Find(".mgen a").Each(func(_ int, s *goquery.Selection) {
		g := strings.TrimSpace(s.Text())
		if g != "" {
			info.Genres = append(info.Genres, g)
		}
	})

	return info, nil
}

func (t *ThunderScans) GetChapters(id string) ([]scrapers.Chapter, error) {
	url := fmt.Sprintf("%s/comics/%s/", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var chapters []scrapers.Chapter

	doc.Find("#chapterlist li").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a")
		href, _ := a.Attr("href")
		if href == "" || href == "#/" {
			return
		}
		title := scrapers.CleanText(a.Find(".chapternum").Text())
		date := scrapers.CleanText(a.Find(".chapterdate").Text())
		slug := scrapers.ExtractLastSegment(href)

		if slug != "" {
			chapters = append(chapters, scrapers.Chapter{
				ID:        slug,
				Title:     title,
				URL:       href,
				UpdatedAt: date,
			})
		}
	})

	return chapters, nil
}

// GetPages extracts images from ts_reader.run({...}) script tag
func (t *ThunderScans) GetPages(chapterID string) ([]string, error) {
	url := fmt.Sprintf("%s/%s/", baseURL, chapterID)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}

	// Extract JSON from ts_reader.run({...})
	re := regexp.MustCompile(`ts_reader\.run\((\{.*?\})\);`)
	match := re.FindSubmatch(body)
	if match == nil {
		return nil, fmt.Errorf("ts_reader.run not found in page")
	}

	// Parse the JSON
	var data struct {
		Sources []struct {
			Source string   `json:"source"`
			Images []string `json:"images"`
		} `json:"sources"`
	}

	if err := json.Unmarshal(match[1], &data); err != nil {
		return nil, fmt.Errorf("failed to parse ts_reader JSON: %w", err)
	}

	if len(data.Sources) == 0 {
		return nil, fmt.Errorf("no sources found")
	}

	return data.Sources[0].Images, nil
}

// --- helpers ---

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

	doc.Find("div.bs").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("div.bsx > a")
		href, _ := a.Attr("href")
		title, _ := a.Attr("title")

		cover := s.Find("img.ts-post-image").AttrOr("src", "")
		if cover == "" {
			cover = s.Find("img").AttrOr("src", "")
		}

		id := scrapers.ExtractLastSegment(href)

		if id != "" && title != "" {
			items = append(items, scrapers.MediaItem{
				ID:       id,
				Title:    title,
				CoverURL: cover,
				URL:      href,
				Source:   "thunderscans",
				Type:     "manga",
			})
		}
	})

	return items, nil
}
