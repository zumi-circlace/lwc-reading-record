import { LightningElement, api } from "lwc";

export default class BookSearchResults extends LightningElement {
    @api results = [];

    get items() {
        return (this.results || []).map((book, index) => ({
            ...book,
            key: `${book.isbn || "noisbn"}-${index}`
        }));
    }

    handleSelect(event) {
        const index = Number(event.currentTarget.dataset.index);
        const book = this.results[index];
        this.dispatchEvent(new CustomEvent("select", { detail: { book } }));
    }
}
