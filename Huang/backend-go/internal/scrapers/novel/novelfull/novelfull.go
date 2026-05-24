package novelfull

import (
	"fmt"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://novelfull.com"

type NovelFull struct{}

func New() *NovelFull { return &NovelFull{} }

func (n *NovelFull) ID() string         { return "novelfull" }
func (n *NovelFull) Name() string       { return "NovelFull" }
func (n *NovelFull) GetBaseURL() string { return baseURL }
func (n *NovelFull) GetType() string    { return "novel" }

func (n *NovelFull) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/most-popular?page=%d", baseURL, page)
	return fetchCards(url)
}

func (n *NovelFull) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/latest-release-novel?page=%d", baseURL, page)
	return fetchCards(url)
}

func (n *NovelFull) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/search?keyword=%s&page=%d", baseURL, q, page)
	return fetchCards(url)
}

func (n *NovelFull) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/%s.html", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	info := &scrapers.MediaInfo{ID: id, Source: "novelfull", Type: "novel"}
	info.Title = scrapers.CleanText(doc.Find("h3.title").First().Text())
	info.CoverURL = doc.Find(".book img").First().AttrOr("src", "")
	if !strings.HasPrefix(info.CoverURL, "http") && info.CoverURL != "" {
		info.CoverURL = baseURL + info.CoverURL
	}
	info.Description = scrapers.CleanText(doc.Find(".desc-text").First().Text())
	info.Author = scrapers.CleanText(doc.Find(".info a[href*=author]").First().Text())
	info.Status = scrapers.CleanText(doc.Find(".info .text-primary").Last().Text())

	doc.Find(".info a[href*=genre]").Each(func(_ int, s *goquery.Selection) {
		g := scrapers.CleanText(s.Text())
		if g != "" {
			info.Genres = append(info.Genres, g)
		}
	})
	return info, nil
}

func (n *NovelFull) GetChapters(id string) ([]scrapers.Chapter, error) {
	// Try page 1 first to get total pages
	url := fmt.Sprintf("%s/%s.html?page=1&per-page=50", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	var chapters []scrapers.Chapter
	chapters = append(chapters, parseChapterLinks(doc, baseURL)...)

	// Get total pages from pagination
	lastPage := 1
	doc.Find(".pagination li a").Each(func(_ int, s *goquery.Selection) {
		href, _ := s.Attr("href")
		if strings.Contains(href, "page=") {
			parts := strings.Split(href, "page=")
			if len(parts) > 1 {
				var p int
				fmt.Sscanf(parts[1], "%d", &p)
				if p > lastPage {
					lastPage = p
				}
			}
		}
	})

	// Fetch remaining pages
	for page := 2; page <= lastPage; page++ {
		pageURL := fmt.Sprintf("%s/%s.html?page=%d&per-page=50", baseURL, id, page)
		pageBody, err := scrapers.FetchHTML(pageURL, baseURL)
		if err != nil {
			break
		}
		pageDoc, err := goquery.NewDocumentFromReader(strings.NewReader(string(pageBody)))
		if err != nil {
			break
		}
		chapters = append(chapters, parseChapterLinks(pageDoc, baseURL)...)
	}

	if len(chapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}
	return chapters, nil
}

func (n *NovelFull) GetPages(chapterID string) ([]string, error) {
	// chapterID = "martial-peak/chapter-1-the-trial-inner-sect-disciple.html"
	chapterID = strings.TrimPrefix(chapterID, "/")
	url := fmt.Sprintf("%s/%s", baseURL, chapterID)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	doc.Find("#chapter-content script, #chapter-content .adsbygoogle, #chapter-content ins").Remove()
	content, err := doc.Find("#chapter-content").Html()
	if err != nil || strings.TrimSpace(content) == "" {
		return nil, fmt.Errorf("no content found for chapter: %s", chapterID)
	}
	return []string{content}, nil
}

func parseChapterLinks(doc *goquery.Document, base string) []scrapers.Chapter {
	var chapters []scrapers.Chapter
	doc.Find("#list-chapter li a").Each(func(_ int, s *goquery.Selection) {
		href, _ := s.Attr("href")
		if href == "" {
			return
		}
		if !strings.HasPrefix(href, "http") {
			href = base + href
		}
		title := scrapers.CleanText(s.Text())
		// ID = path without leading slash: "martial-peak/chapter-1.html"
		slug := strings.TrimPrefix(href, base+"/")
		chapters = append(chapters, scrapers.Chapter{
			ID: slug, Title: title, URL: href,
		})
	})
	return chapters
}

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
	doc.Find(".list-truyen .row").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("h3.truyen-title a").First()
		href, _ := a.Attr("href")
		if href == "" {
			return
		}
		if !strings.HasPrefix(href, "http") {
			href = baseURL + href
		}
		title := scrapers.CleanText(a.Text())
		cover := s.Find("img.cover").First().AttrOr("src", "")
		if !strings.HasPrefix(cover, "http") && cover != "" {
			cover = baseURL + cover
		}
		latestChap := scrapers.CleanText(s.Find(".chapter-text").First().Text())

		// ID = slug without .html: "martial-peak"
		id := strings.TrimPrefix(href, baseURL+"/")
		id = strings.TrimSuffix(id, ".html")

		if id != "" && title != "" {
			items = append(items, scrapers.MediaItem{
				ID:         id,
				Title:      title,
				CoverURL:   cover,
				URL:        href,
				Source:     "novelfull",
				Type:       "novel",
				LatestChap: latestChap,
			})
		}
	})
	return items, nil
}
