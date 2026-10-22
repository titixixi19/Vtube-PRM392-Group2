package com.vtube.api.search;

import com.vtube.api.auth.Auth;
import com.vtube.api.common.Paging;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Search", description = "Màn 9, 10 - Tìm kiếm")
@RestController
@RequestMapping("/api")
public class SearchController {
    private final SearchService search;

    public SearchController(SearchService search) {
        this.search = search;
    }

    /**
     * type: all | video | short | channel | playlist | unwatched
     * uploadDate: today | week | month | year
     * duration: short (&lt;4 phút) | medium (4-20 phút) | long (&gt;20 phút)
     * sort: relevance | date | views | rating
     */
    @GetMapping("/search")
    public SearchService.SearchResult search(@RequestParam String q,
                                             @RequestParam(defaultValue = "all") String type,
                                             @RequestParam(required = false) String uploadDate,
                                             @RequestParam(required = false) String duration,
                                             @RequestParam(defaultValue = "relevance") String sort,
                                             @RequestParam(required = false) Integer page,
                                             @RequestParam(required = false) Integer size) {
        return search.search(Auth.userId(), q, new SearchService.Filters(type, uploadDate, duration, sort),
                Paging.of(page, size));
    }

    @GetMapping("/search/suggestions")
    public SearchService.Suggestions suggestions(@RequestParam(defaultValue = "") String q) {
        return search.suggestions(Auth.userId(), q);
    }

    @GetMapping("/me/search-history")
    public List<SearchService.HistoryEntry> history() {
        return search.history(Auth.requireUserId());
    }

    /** Có keyword: xóa 1 mục. Không có keyword: xóa toàn bộ. */
    @DeleteMapping("/me/search-history")
    public ResponseEntity<Void> deleteHistory(@RequestParam(required = false) String keyword) {
        search.deleteHistory(Auth.requireUserId(), keyword);
        return ResponseEntity.noContent().build();
    }
}
