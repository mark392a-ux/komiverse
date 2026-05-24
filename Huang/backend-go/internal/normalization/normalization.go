package normalization

import (
	"strings"
	"unicode"

	"HUANG/backend/internal/scrapers"
)

func NormalizeTitle(input string) string {
	input = strings.ToLower(strings.TrimSpace(input))
	if input == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(input))
	lastSpace := false
	for _, r := range input {
		if unicode.IsLetter(r) || unicode.IsNumber(r) {
			b.WriteRune(r)
			lastSpace = false
			continue
		}
		if !lastSpace {
			b.WriteByte(' ')
			lastSpace = true
		}
	}
	return strings.TrimSpace(b.String())
}

func NormalizeMediaItem(item scrapers.MediaItem) scrapers.MediaItem {
	item.Title = strings.TrimSpace(item.Title)
	item.CoverURL = strings.TrimSpace(item.CoverURL)
	item.URL = strings.TrimSpace(item.URL)
	item.Source = strings.TrimSpace(item.Source)
	item.Type = strings.TrimSpace(item.Type)
	item.LatestChap = strings.TrimSpace(item.LatestChap)
	item.UpdatedAt = strings.TrimSpace(item.UpdatedAt)
	return item
}

func NormalizeMediaInfo(info *scrapers.MediaInfo) *scrapers.MediaInfo {
	if info == nil {
		return nil
	}
	info.Title = strings.TrimSpace(info.Title)
	info.CoverURL = strings.TrimSpace(info.CoverURL)
	info.Description = strings.TrimSpace(info.Description)
	info.Author = strings.TrimSpace(info.Author)
	info.Artist = strings.TrimSpace(info.Artist)
	info.Status = strings.TrimSpace(info.Status)
	info.Type = strings.TrimSpace(info.Type)
	info.Source = strings.TrimSpace(info.Source)
	for i, g := range info.Genres {
		info.Genres[i] = strings.TrimSpace(g)
	}
	for i, t := range info.AltTitles {
		info.AltTitles[i] = strings.TrimSpace(t)
	}
	return info
}

func DedupeMediaItems(items []scrapers.MediaItem) []scrapers.MediaItem {
	seen := make(map[string]struct{}, len(items))
	out := make([]scrapers.MediaItem, 0, len(items))
	for _, item := range items {
		n := NormalizeMediaItem(item)
		key := strings.TrimSpace(n.ID)
		if key == "" {
			key = NormalizeTitle(n.Title)
		}
		if key == "" {
			continue
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, n)
	}
	return out
}
