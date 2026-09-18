import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import searchByIsbn from "@salesforce/apex/BookScannerController.searchByIsbn";
import findMyLogsForIsbn from "@salesforce/apex/BookScannerController.findMyLogsForIsbn";

const SCAN_STORAGE_KEY = "readingLog.lastBarcodeScan";

export default class ReadingLogEntry extends LightningElement {
    activeTab = "camera";
    showConfirm = false;
    @track selectedBook = {};
    @track existingLogs = [];
    @track lastScanPayload;
    searchResetKey = 0;

    connectedCallback() {
        this.restoreScanPayload();
    }

    get hasExistingLogs() {
        return this.existingLogs && this.existingLogs.length > 0;
    }

    handleTabActive(event) {
        this.activeTab = event.target.value;
    }

    handleScanResult(event) {
        this.applyScanPayload(event.detail);
    }

    restoreScanPayload() {
        try {
            const raw = sessionStorage.getItem(SCAN_STORAGE_KEY);
            if (!raw) {
                return;
            }
            this.applyScanPayload(JSON.parse(raw));
        } catch (error) {
            sessionStorage.removeItem(SCAN_STORAGE_KEY);
        }
    }

    applyScanPayload(payload) {
        if (!payload) {
            return;
        }
        this.lastScanPayload = payload;
        this.activeTab = "camera";
        const isbn = payload.isbn;
        const firstValue = payload.items?.find((item) => item.value)?.value;
        if (isbn) {
            this.lookupIsbnAndConfirm(isbn, "カメラ");
            return;
        }
        if (firstValue) {
            this.toast(
                "warning",
                "それ下段じゃね？",
                `読み取り: ${firstValue}。上段の 978 / 979 をスキャンしてください。`
            );
        }
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
        this.clearStoredScan();
        this.toast("info", "手打ちへ", "書誌が見つかりませんでした。タイトルなどを入力してください。");
    }

    handleConfirmCancel() {
        this.showConfirm = false;
    }

    handleSaved() {
        this.showConfirm = false;
        this.selectedBook = {};
        this.existingLogs = [];
        this.lastScanPayload = undefined;
        this.searchResetKey += 1;
        this.clearStoredScan();
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
        this.clearStoredScan();
    }

    clearStoredScan() {
        try {
            sessionStorage.removeItem(SCAN_STORAGE_KEY);
        } catch (error) {
            // ignore
        }
    }

    toast(variant, title, message) {
        this.dispatchEvent(new ShowToastEvent({ variant, title, message }));
    }

    messageOf(error) {
        return error?.body?.message || error?.message || "不明なエラーです";
    }
}
