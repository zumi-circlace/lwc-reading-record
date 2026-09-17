import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import saveReadingLog from "@salesforce/apex/BookScannerController.saveReadingLog";

export default class ReadingLogConfirm extends NavigationMixin(LightningElement) {
    @api existingLogs = [];

    _book = {};
    title = "";
    isbn = "";
    author = "";
    publisher = "";
    publishedYear = "";
    coverUrl = "";
    category = "";
    description = "";
    readDate;
    saving = false;

    categoryOptions = [
        { label: "小説", value: "小説" },
        { label: "ビジネス", value: "ビジネス" },
        { label: "技術書", value: "技術書" },
        { label: "趣味", value: "趣味" },
        { label: "漫画", value: "漫画" },
        { label: "その他", value: "その他" }
    ];

    @api
    get book() {
        return this._book;
    }
    set book(value) {
        this._book = value || {};
        this.title = this._book.title || "";
        this.isbn = this._book.isbn || "";
        this.author = this._book.author || "";
        this.publisher = this._book.publisher || "";
        this.publishedYear = this._book.publishedYear || "";
        this.coverUrl = this._book.coverUrl || "";
        this.category = this._book.category || "";
        this.readDate = this.toIsoDate(new Date());
    }

    get hasExistingLogs() {
        return this.existingLogs && this.existingLogs.length > 0;
    }

    get hasCover() {
        return Boolean(this.coverUrl);
    }

    toIsoDate(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, "0");
        const day = String(date.getDate()).padStart(2, "0");
        return `${year}-${month}-${day}`;
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent("cancel"));
    }

    handleOpenExisting(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId,
                objectApiName: "ReadingLog__c",
                actionName: "view"
            }
        });
    }

    async handleSave() {
        if (!this.title || !this.readDate) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "入力を確認してください",
                    message: "タイトルと読了日は必須です。",
                    variant: "error"
                })
            );
            return;
        }
        this.saving = true;
        try {
            await saveReadingLog({
                request: {
                    bookId: this._book.bookId,
                    title: this.title,
                    isbn: this.isbn,
                    author: this.author,
                    publisher: this.publisher,
                    publishedYear: this.publishedYear,
                    coverUrl: this.coverUrl,
                    category: this.category,
                    readDate: this.readDate,
                    description: this.description
                }
            });
            this.dispatchEvent(new CustomEvent("saved"));
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "保存に失敗しました",
                    message: error?.body?.message || error?.message || "もう一度試してください。",
                    variant: "error"
                })
            );
        } finally {
            this.saving = false;
        }
    }
}
