import { LightningElement, api, track } from "lwc";
import searchBooks from "@salesforce/apex/BookScannerController.searchBooks";

export default class BookSearch extends LightningElement {
    @api
    get resetKey() {
        return this._resetKey;
    }
    set resetKey(value) {
        this._resetKey = value;
        this.query = "";
        this.results = [];
        this.errorMessage = undefined;
        this.searched = false;
    }

    query = "";
    isLoading = false;
    searched = false;
    errorMessage;
    @track results = [];
    _resetKey = 0;

    get hasResults() {
        return this.results.length > 0;
    }

    get noResults() {
        return this.searched && !this.isLoading && this.results.length === 0 && !this.errorMessage;
    }

    handleQueryChange(event) {
        this.query = event.target.value;
    }

    handleKeydown(event) {
        if (event.key === "Enter") {
            this.handleSearch();
        }
    }

    async handleSearch() {
        if (!this.query || !this.query.trim()) {
            this.errorMessage = "ISBN またはタイトルを入力してください。";
            return;
        }
        this.isLoading = true;
        this.errorMessage = undefined;
        this.searched = true;
        try {
            const data = await searchBooks({ query: this.query.trim() });
            this.results = data || [];
            if (this.results.length === 1) {
                this.dispatchEvent(
                    new CustomEvent("bookselected", { detail: { book: this.results[0] } })
                );
            }
        } catch (error) {
            this.results = [];
            this.errorMessage = error?.body?.message || error?.message || "検索に失敗しました。";
        } finally {
            this.isLoading = false;
        }
    }

    handleSelect(event) {
        this.dispatchEvent(new CustomEvent("bookselected", { detail: { book: event.detail.book } }));
    }

    handleManual() {
        this.dispatchEvent(new CustomEvent("needmanual"));
    }
}
