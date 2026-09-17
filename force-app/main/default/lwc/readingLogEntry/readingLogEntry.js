import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import searchByIsbn from "@salesforce/apex/BookScannerController.searchByIsbn";
import findMyLogsForIsbn from "@salesforce/apex/BookScannerController.findMyLogsForIsbn";

export default class ReadingLogEntry extends LightningElement {
    activeTab = "search";
    showConfirm = false;
    @track selectedBook = {};
    @track existingLogs = [];
    searchResetKey = 0;

    get hasExistingLogs() {
        return this.existingLogs && this.existingLogs.length > 0;
    }

    handleTabActive(event) {
        this.activeTab = event.target.value;
    }

    async handleIsbnScanned(event) {
        const isbn = event.detail.isbn;
        await this.lookupIsbnAndConfirm(isbn, "カメラ");
    }

    async handleBookSelected(event) {
        await this.openConfirm(event.detail.book);
    }

    handleManualContinue(event) {
        this.openConfirm({
            ...event.detail.book,
            source: "Manual"
        });
    }

    handleNeedManual() {
        this.activeTab = "manual";
        this.toast("info", "手打ちへ", "書誌が見つかりませんでした。タイトルなどを入力してください。");
    }

    handleConfirmCancel() {
        this.showConfirm = false;
    }

    handleSaved() {
        this.showConfirm = false;
        this.selectedBook = {};
        this.existingLogs = [];
        this.searchResetKey += 1;
        this.toast("success", "保存しました", "記録一覧から確認できます。");
    }

    async lookupIsbnAndConfirm(isbn, sourceLabel) {
        try {
            const results = await searchByIsbn({ isbn });
            if (!results || results.length === 0) {
                this.handleNeedManual();
                return;
            }
            const book = { ...results[0], source: results[0].source || sourceLabel };
            await this.openConfirm(book);
        } catch (error) {
            this.toast("error", "ISBN検索に失敗", this.messageOf(error));
        }
    }

    async openConfirm(book) {
        this.selectedBook = { ...book };
        this.existingLogs = [];
        if (book && book.isbn) {
            try {
                this.existingLogs = await findMyLogsForIsbn({ isbn: book.isbn });
            } catch (error) {
                this.toast("error", "既存記録の確認に失敗", this.messageOf(error));
            }
        }
        this.showConfirm = true;
    }

    toast(variant, title, message) {
        this.dispatchEvent(new ShowToastEvent({ variant, title, message }));
    }

    messageOf(error) {
        return error?.body?.message || error?.message || "不明なエラーです";
    }
}
