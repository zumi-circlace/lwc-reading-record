import { LightningElement } from "lwc";

export default class ManualBookForm extends LightningElement {
    title = "";
    isbn = "";
    author = "";
    publisher = "";
    publishedYear = "";
    category = "";

    categoryOptions = [
        { label: "小説", value: "小説" },
        { label: "ビジネス", value: "ビジネス" },
        { label: "技術書", value: "技術書" },
        { label: "趣味", value: "趣味" },
        { label: "漫画", value: "漫画" },
        { label: "その他", value: "その他" }
    ];

    handleChange(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    handleContinue() {
        if (!this.title || !this.title.trim()) {
            this.template.querySelector("[data-field=title]").reportValidity();
            return;
        }
        this.dispatchEvent(
            new CustomEvent("continue", {
                detail: {
                    book: {
                        title: this.title.trim(),
                        isbn: this.isbn,
                        author: this.author,
                        publisher: this.publisher,
                        publishedYear: this.publishedYear,
                        category: this.category,
                        source: "Manual"
                    }
                }
            })
        );
    }
}
