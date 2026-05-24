package novelbin

import (
	"fmt"
	"regexp"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://novelbin.com"

type NovelBin struct{}

func New() *NovelBin { return &NovelBin{} }

func (n *NovelBin) ID() string         { return "novelbin" }
func (n *NovelBin) Name() string       { return "NovelBin" }
func (n *NovelBin) GetBaseURL() string { return baseURL }
func (n *NovelBin) GetType() string    { return "novel" }

func (n *NovelBin) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/sort/top-view-novel?page=%d", baseURL, page)
	return fetchCards(url)
}

func (n *NovelBin) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/sort/novelbin-daily-update?page=%d", baseURL, page)
	return fetchCards(url)
}

func (n *NovelBin) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := strings.ReplaceAll(query, " ", "+")
	url := fmt.Sprintf("%s/search?keyword=%s&page=%d", baseURL, q, page)
	return fetchCards(url)
}

func (n *NovelBin) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/b/%s", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	info := &scrapers.MediaInfo{ID: id, Source: "novelbin", Type: "novel"}
	info.Title = scrapers.CleanText(doc.Find("h3.title").First().Text())
	if info.Title == "" {
		info.Title = scrapers.CleanText(doc.Find("h1.title, h3.title, .title").First().Text())
	}
	info.CoverURL = doc.Find(".book img").First().AttrOr("src", "")
	info.Description = scrapers.CleanText(doc.Find(".desc-text").First().Text())
	info.Author = scrapers.CleanText(doc.Find(".info a[href*=author]").First().Text())

	doc.Find(".info a[href*=genre]").Each(func(_ int, s *goquery.Selection) {
		g := scrapers.CleanText(s.Text())
		if g != "" {
			info.Genres = append(info.Genres, g)
		}
	})
	return info, nil
}

func (n *NovelBin) GetChapters(id string) ([]scrapers.Chapter, error) {
	ajaxURL := fmt.Sprintf("%s/ajax/chapter-archive?novelId=%s", baseURL, id)
	body, err := scrapers.FetchHTML(ajaxURL, baseURL)
	if err == nil {
		if chapters := parseChaptersFromHTML(id, body); len(chapters) > 0 {
			return chapters, nil
		}
	}

	// Fallback to the novel page when ajax is unavailable or unexpectedly empty.
	pageBody, err := scrapers.FetchHTML(fmt.Sprintf("%s/b/%s", baseURL, id), baseURL)
	if err != nil {
		return nil, err
	}
	chapters := parseChaptersFromHTML(id, pageBody)
	if len(chapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}
	return chapters, nil
}

func parseChaptersFromHTML(id string, body []byte) []scrapers.Chapter {
	chapters := make([]scrapers.Chapter, 0, 512)
	seen := make(map[string]struct{})
	add := func(href, title string) {
		if href == "" {
			return
		}
		if !strings.HasPrefix(href, "http") {
			href = baseURL + href
		}
		slug := strings.TrimPrefix(href, baseURL+"/")
		slug = strings.TrimRight(slug, "/")
		if slug == "" {
			return
		}
		if _, ok := seen[slug]; ok {
			return
		}
		seen[slug] = struct{}{}

		cleanTitle := scrapers.CleanText(title)
		if cleanTitle == "" {
			last := scrapers.ExtractLastSegment(slug)
			cleanTitle = strings.ReplaceAll(last, "-", " ")
		}
		chapters = append(chapters, scrapers.Chapter{
			ID:    slug,
			Title: cleanTitle,
			URL:   href,
		})
	}

	// Primary selectors used by both the normal page and ajax chapter archive.
	if doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body))); err == nil {
		doc.Find("ul.list-chapter li a, #list-chapter li a, #chapter-archive li a").Each(func(_ int, s *goquery.Selection) {
			href, _ := s.Attr("href")
			add(href, s.Text())
		})
	}

	// Some newer layouts hide links in raw HTML templates; parse direct URLs as a fallback.
	if len(chapters) == 0 {
		pattern := fmt.Sprintf(`https?://(?:www\.)?novelbin\.com/b/%s/chapter-[^"'<>\s]+`, regexp.QuoteMeta(id))
		re := regexp.MustCompile(pattern)
		matches := re.FindAllString(string(body), -1)
		for _, href := range matches {
			add(href, "")
		}
	}

	return chapters
}

func (n *NovelBin) GetPages(chapterID string) ([]string, error) {
	// chapterID = "b/super-gene/chapter-1"
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

	// Remove ads and scripts
	doc.Find("#chr-content .ads, #chr-content script, #chr-content .adsbygoogle").Remove()

	content, err := doc.Find("#chr-content").Html()
	if err != nil || strings.TrimSpace(content) == "" {
		content, err = doc.Find(".chr-c").Html()
		if err != nil || strings.TrimSpace(content) == "" {
			return nil, fmt.Errorf("no content found for chapter: %s", chapterID)
		}
	}
	return []string{content}, nil
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

	doc.Find(".col-novel, .list-novel .row").Each(func(_ int, s *goquery.Selection) {
		a := s.Find(".novel-title a").First()
		href, _ := a.Attr("href")
		if href == "" {
			a = s.Find("a").First()
			href, _ = a.Attr("href")
		}
		if href == "" {
			return
		}
		if !strings.HasPrefix(href, "http") {
			href = baseURL + href
		}

		title := scrapers.CleanText(a.Text())
		cover := s.Find("img").First().AttrOr("data-src", "")
		if cover == "" {
			cover = s.Find("img").First().AttrOr("src", "")
		}
		latestChap := scrapers.CleanText(s.Find(".chr-text, .novel-stats .chapter").First().Text())

		// Extract slug from URL — works for both /b/{slug} and /novel/{slug}
		id := scrapers.ExtractLastSegment(href)

		if id != "" && title != "" {
			items = append(items, scrapers.MediaItem{
				ID:         id,
				Title:      title,
				CoverURL:   cover,
				URL:        href,
				Source:     "novelbin",
				Type:       "novel",
				LatestChap: latestChap,
			})
		}
	})
	return items, nil
}
