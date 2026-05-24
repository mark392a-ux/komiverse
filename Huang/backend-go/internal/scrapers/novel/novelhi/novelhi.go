package novelhi

import (
	"encoding/json"
	"fmt"
	"net/url"
	"strings"

	"HUANG/backend/internal/scrapers"

	"github.com/PuerkitoBio/goquery"
)

const baseURL = "https://novelhi.com"

type NovelHi struct{}

func New() *NovelHi { return &NovelHi{} }

func (n *NovelHi) ID() string         { return "novelhi" }
func (n *NovelHi) Name() string       { return "NovelHi" }
func (n *NovelHi) GetBaseURL() string { return baseURL }
func (n *NovelHi) GetType() string    { return "novel" }

func (n *NovelHi) Popular(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/book/listUpdateRank?pageIndex=%d&pageSize=20&rankType=MONTH", baseURL, page)
	return fetchCardsFromAPI(url)
}

func (n *NovelHi) Latest(page int) ([]scrapers.MediaItem, error) {
	url := fmt.Sprintf("%s/book/listUpdateRank?pageIndex=%d&pageSize=20&rankType=NEW", baseURL, page)
	return fetchCardsFromAPI(url)
}

func (n *NovelHi) Search(query string, page int) ([]scrapers.MediaItem, error) {
	q := url.QueryEscape(strings.TrimSpace(query))
	searchURL := fmt.Sprintf("%s/book/searchByPageInShelf?curr=%d&limit=20&keyword=%s", baseURL, page, q)
	return fetchCardsFromSearchAPI(searchURL)
}

func (n *NovelHi) GetInfo(id string) (*scrapers.MediaInfo, error) {
	url := fmt.Sprintf("%s/s/%s", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	info := &scrapers.MediaInfo{ID: id, Source: "novelhi", Type: "novel"}
	info.Title = scrapers.CleanText(doc.Find(".tit h1").First().Text())
	info.CoverURL = doc.Find("img.cover").First().AttrOr("src", "")
	info.Description = scrapers.CleanText(doc.Find("p.detail-desc").First().Text())

	doc.Find("ul.list span.item").Each(func(_ int, s *goquery.Selection) {
		text := scrapers.CleanText(s.Text())
		em := scrapers.CleanText(s.Find("em").Text())
		if strings.HasPrefix(text, "Status:") {
			info.Status = em
		} else if strings.HasPrefix(text, "Author:") {
			info.Author = em
		}
	})

	// Fetch genres via API
	bookId, _ := doc.Find("input#bookId").Attr("value")
	if bookId != "" {
		genreBody, err := scrapers.FetchAjax(
			fmt.Sprintf("%s/book/queryBookGenre?bookId=%s", baseURL, bookId), url)
		if err == nil {
			var genreResp struct {
				Data []struct {
					GenreName string `json:"genreName"`
				} `json:"data"`
			}
			if json.Unmarshal(genreBody, &genreResp) == nil {
				for _, g := range genreResp.Data {
					if g.GenreName != "" {
						info.Genres = append(info.Genres, g.GenreName)
					}
				}
			}
		}
	}

	return info, nil
}

func (n *NovelHi) GetChapters(id string) ([]scrapers.Chapter, error) {
	// Get bookId from series page
	url := fmt.Sprintf("%s/s/%s", baseURL, id)
	body, err := scrapers.FetchHTML(url, baseURL)
	if err != nil {
		return nil, err
	}
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}

	bookId, exists := doc.Find("input#bookId").Attr("value")
	if !exists || bookId == "" {
		return nil, fmt.Errorf("could not find bookId for: %s", id)
	}

	// Fetch all chapters at once
	chapURL := fmt.Sprintf("%s/book/queryIndexList?bookId=%s&curr=1&limit=10000", baseURL, bookId)
	chapBody, err := scrapers.FetchAjax(chapURL, url)
	if err != nil {
		return nil, err
	}

	var result struct {
		Data struct {
			List []struct {
				Id         string `json:"id"`
				IndexName  string `json:"indexName"`
				IndexNum   string `json:"indexNum"`
				CreateTime string `json:"createTime"`
			} `json:"list"`
		} `json:"data"`
	}

	if err := json.Unmarshal(chapBody, &result); err != nil {
		return nil, fmt.Errorf("failed to parse chapters: %w", err)
	}

	var chapters []scrapers.Chapter
	list := result.Data.List
	// Reverse to ascending order (API returns newest first)
	for i := len(list) - 1; i >= 0; i-- {
		ch := list[i]
		// URL uses chapter number (e.g. /s/Martial-Peak/1), not the long ID
		chURL := fmt.Sprintf("%s/s/%s/%s", baseURL, id, ch.IndexNum)
		chapters = append(chapters, scrapers.Chapter{
			ID:        fmt.Sprintf("s/%s/%s", id, ch.IndexNum),
			Title:     ch.IndexName,
			Number:    ch.IndexNum,
			URL:       chURL,
			UpdatedAt: ch.CreateTime,
		})
	}

	if len(chapters) == 0 {
		return nil, fmt.Errorf("no chapters found for: %s", id)
	}
	return chapters, nil
}

func (n *NovelHi) GetPages(chapterID string) ([]string, error) {
	// chapterID = "s/Martial-Peak/1"
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

	// Remove ads and scripts from content
	doc.Find("#showReading script, #showReading .adsbygoogle, #showReading ins").Remove()

	content, err := doc.Find("#showReading").Html()
	if err != nil || strings.TrimSpace(content) == "" {
		return nil, fmt.Errorf("no content found for chapter: %s", chapterID)
	}
	return []string{content}, nil
}

// --- helpers ---

func fetchCardsFromAPI(url string) ([]scrapers.MediaItem, error) {
	body, err := scrapers.FetchAjax(url, baseURL)
	if err != nil {
		return fetchCards(baseURL + "/")
	}

	var result struct {
		Data []novelHiBook `json:"data"`
	}

	if err := json.Unmarshal(body, &result); err != nil {
		return fetchCards(baseURL + "/")
	}

	return buildItemsFromBooks(result.Data), nil
}

func fetchCardsFromSearchAPI(url string) ([]scrapers.MediaItem, error) {
	body, err := scrapers.FetchAjax(url, baseURL)
	if err != nil {
		return nil, err
	}

	var result struct {
		Data struct {
			List []novelHiBook `json:"list"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, err
	}

	return buildItemsFromBooks(result.Data.List), nil
}

type novelHiBook struct {
	BookName       string `json:"bookName"`
	BookSimpleName string `json:"bookSimpleName"`
	SimpleName     string `json:"simpleName"`
	CoverImg       string `json:"coverImg"`
	PicURL         string `json:"picUrl"`
	LastIndexName  string `json:"lastIndexName"`
}

func buildItemsFromBooks(books []novelHiBook) []scrapers.MediaItem {
	items := make([]scrapers.MediaItem, 0, len(books))
	for _, b := range books {
		id := strings.TrimSpace(b.BookSimpleName)
		if id == "" {
			id = strings.TrimSpace(b.SimpleName)
		}
		if id == "" {
			continue
		}
		cover := strings.TrimSpace(b.CoverImg)
		if cover == "" {
			cover = strings.TrimSpace(b.PicURL)
		}
		items = append(items, scrapers.MediaItem{
			ID:         id,
			Title:      strings.TrimSpace(b.BookName),
			CoverURL:   cover,
			URL:        fmt.Sprintf("%s/s/%s", baseURL, id),
			Source:     "novelhi",
			Type:       "novel",
			LatestChap: strings.TrimSpace(b.LastIndexName),
		})
	}

	return items
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
	doc.Find("li.home_img_li").Each(func(_ int, s *goquery.Selection) {
		a := s.Find("a.home_book").First()
		href, _ := a.Attr("href")
		if href == "" {
			href, _ = s.Find("a.shadow_img").First().Attr("href")
		}
		if href == "" {
			return
		}
		if !strings.HasPrefix(href, "http") {
			href = baseURL + href
		}
		title := scrapers.CleanText(a.Text())
		img := s.Find("img.lazyload, img").First()
		cover := img.AttrOr("data-src", "")
		if cover == "" {
			cover = img.AttrOr("src", "")
		}
		latestChap := scrapers.CleanText(s.Find(".lh40 a").Last().Text())
		id := strings.TrimPrefix(href, baseURL+"/s/")
		id = strings.TrimRight(id, "/")

		if id != "" && title != "" {
			items = append(items, scrapers.MediaItem{
				ID: id, Title: title, CoverURL: cover,
				URL: href, Source: "novelhi", Type: "novel",
				LatestChap: latestChap,
			})
		}
	})
	return items, nil
}
