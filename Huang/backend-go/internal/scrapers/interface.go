package scrapers

// Source is the interface every single scraper must implement
// If a scraper doesn't implement all these methods, it won't compile
type Source interface {
	ID() string         // unique key: "mangafire", "asura", "novelbin"
	Name() string       // display name: "MangaFire", "Asura Comics"
	GetBaseURL() string // "https://mangafire.to"
	GetType() string    // "manga", "anime", "novel"

	// Browse
	Popular(page int) ([]MediaItem, error)
	Latest(page int) ([]MediaItem, error)
	Search(query string, page int) ([]MediaItem, error)

	// Detail page
	GetInfo(id string) (*MediaInfo, error)
	GetChapters(id string) ([]Chapter, error)

	// Reading - returns list of image URLs for manga, text for novels
	GetPages(chapterID string) ([]string, error)
}

// MediaItem - a single card shown in browse/search lists
type MediaItem struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	CoverURL   string `json:"cover_url"`
	URL        string `json:"url"`
	Source     string `json:"source"`
	Type       string `json:"type"`
	LatestChap string `json:"latest_chapter,omitempty"`
	UpdatedAt  string `json:"updated_at,omitempty"`
}

// MediaInfo - full detail of a manga/anime/novel
type MediaInfo struct {
	ID          string   `json:"id"`
	Title       string   `json:"title"`
	AltTitles   []string `json:"alt_titles,omitempty"`
	CoverURL    string   `json:"cover_url"`
	Description string   `json:"description"`
	Author      string   `json:"author"`
	Artist      string   `json:"artist,omitempty"`
	Status      string   `json:"status"`
	Genres      []string `json:"genres"`
	Type        string   `json:"type"`
	Source      string   `json:"source"`
	TotalChaps  int      `json:"total_chapters,omitempty"`
}

// Chapter - a single chapter entry
type Chapter struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Number    string `json:"number"`
	URL       string `json:"url"`
	Language  string `json:"language,omitempty"`
	UpdatedAt string `json:"updated_at,omitempty"`
}
