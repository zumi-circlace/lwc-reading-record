import { LightningElement, api, track } from "lwc";
import searchBooks from "@salesforce/apex/BookScannerController.searchBooks";

const PAGE_SIZE = 20;
const ORDER_OPTIONS = [
    { label: "関連度順", value: "relevance" },
    { label: "新しい順", value: "newest" }
];

export default class BookSearch extends LightningElement {
    @api
    get resetKey() {
        return this._resetKey;
    }
    set resetKey(value) {
        this._resetKey = value;
        this.query = "";
        this.author = "";
        this.orderBy = "relevance";
        this.results = [];
        this.errorMessage = undefined;
        this.searched = false;
        this.startIndex = 0;
        this.hasNext = false;
        this.hasPrevious = false;
        this.paged = false;
    }

    query = "";
    author = "";
    orderBy = "relevance";
    orderOptions = ORDER_OPTIONS;
    isLoading = false;
    searched = false;
    errorMessage;
    startIndex = 0;
    hasNext = false;
    hasPrevious = false;
    paged = false;
    @track results = [];
    _resetKey = 0;
    _scrollAfterSearch = false;
    _pendingScroll = false;

    get hasResults() {
        return this.results.length > 0;
    }

    get noResults() {
        return this.searched && !this.isLoading && this.results.length === 0 && !this.errorMessage && !this.hasPrevious;
    }

    get showPager() {
        return this.paged && (this.hasPrevious || this.hasNext) && !this.isLoading;
    }

    get rangeLabel() {
        if (!this.results.length) {
            return "";
        }
        const from = this.startIndex + 1;
        const to = this.startIndex + this.results.length;
        return `${from}–${to}件`;
    }

    get isPreviousDisabled() {
        return !this.hasPrevious;
    }

    get isNextDisabled() {
        return !this.hasNext;
    }

    renderedCallback() {
        if (!this._pendingScroll) {
            return;
        }
        this._pendingScroll = false;
        this.scrollSearchIntoView();
    }

    handleQueryChange(event) {
        this.query = event.target.value;
    }

    handleAuthorChange(event) {
        this.author = event.target.value;
    }

    handleOrderByChange(event) {
        this.orderBy = event.detail.value;
        if (this.searched && this.hasSearchInput()) {
            this.startIndex = 0;
            this.runSearch();
        }
    }

    handleKeydown(event) {
        if (event.key === "Enter") {
            this.handleSearch();
        }
    }

    handleSearch() {
        this.startIndex = 0;
        this.runSearch();
    }

    handlePrevious() {
        this.startIndex = Math.max(0, this.startIndex - PAGE_SIZE);
        this._scrollAfterSearch = true;
        this.runSearch();
    }

    handleNext() {
        this.startIndex = this.startIndex + PAGE_SIZE;
        this._scrollAfterSearch = true;
        this.runSearch();
    }

    hasSearchInput() {
        return Boolean((this.query && this.query.trim()) || (this.author && this.author.trim()));
    }

    async runSearch() {
        if (!this.hasSearchInput()) {
            this._scrollAfterSearch = false;
            this.errorMessage = "ISBN、タイトル、または著者名を入力してください。";
            return;
        }
        this.isLoading = true;
        this.errorMessage = undefined;
        this.searched = true;
        try {
            const page = await searchBooks({
                query: (this.query || "").trim(),
                startIndex: this.startIndex,
                author: (this.author || "").trim() || null,
                orderBy: this.orderBy
            });
            this.results = page?.books || [];
            this.startIndex = page?.startIndex || 0;
            this.hasNext = Boolean(page?.hasNext);
            this.hasPrevious = Boolean(page?.hasPrevious);
            this.paged = Boolean(page?.paged);
            if (this.startIndex === 0 && this.results.length === 1) {
                this.dispatchEvent(
                    new CustomEvent("bookselected", { detail: { book: this.results[0] } })
                );
            }
        } catch (error) {
            this.results = [];
            this.hasNext = false;
            this.hasPrevious = false;
            this.paged = false;
            this.errorMessage = error?.body?.message || error?.message || "検索に失敗しました。";
        } finally {
            this.isLoading = false;
            if (this._scrollAfterSearch) {
                this._pendingScroll = true;
                this._scrollAfterSearch = false;
            }
        }
    }

    scrollSearchIntoView() {
        const anchor = this.template.querySelector("[data-id=\"search-anchor\"]");
        if (anchor && typeof anchor.scrollIntoView === "function") {
            anchor.scrollIntoView({ behavior: "smooth", block: "start", inline: "nearest" });
        }
    }

    handleSelect(event) {
        this.dispatchEvent(new CustomEvent("bookselected", { detail: { book: event.detail.book } }));
    }

    handleManual() {
        this.dispatchEvent(new CustomEvent("needmanual"));
    }
}
