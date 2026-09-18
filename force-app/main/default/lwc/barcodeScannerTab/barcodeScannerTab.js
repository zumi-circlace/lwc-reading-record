import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getBarcodeScanner } from "lightning/mobileCapabilities";

const SCAN_STORAGE_KEY = "readingLog.lastBarcodeScan";

export default class BarcodeScannerTab extends LightningElement {
    scanner;
    scanning = false;
    retryHint;
    scanSessionId = 0;
    rawDump;
    scannedItems = [];
    _scanPayload;

    @api
    get scanPayload() {
        return this._scanPayload;
    }
    set scanPayload(value) {
        this._scanPayload = value;
        if (value && (value.items?.length || value.rawDump)) {
            this.scannedItems = value.items || [];
            this.rawDump = value.rawDump;
        }
    }

    get scannerAvailable() {
        return this.scanner && this.scanner.isAvailable();
    }

    get hasScanResult() {
        return Boolean(this.rawDump) || this.scannedItems.length > 0;
    }

    connectedCallback() {
        this.scanner = getBarcodeScanner();
    }

    disconnectedCallback() {
        this.scanSessionId += 1;
        this.scanning = false;
    }

    async handleScan() {
        if (!this.scannerAvailable || this.scanning) {
            return;
        }
        const instructionText =
            this.retryHint || "スキャンラインを上段のISBNに合わせてください";
        this.scanning = true;
        try {
            const result = await this.scanner.scan(this.buildScanOptions(instructionText));
            const rawDump = this.safeStringify(result);
            const scannedItems = this.normalizeBarcodes(result, rawDump);
            this.rawDump = rawDump;
            this.scannedItems = scannedItems;

            if (scannedItems.some((item) => item.isIsbn)) {
                this.retryHint = undefined;
                this.publishItems(scannedItems, rawDump);
                return;
            }

            if (!scannedItems.some((item) => item.value)) {
                this.toast("warning", "値が取れませんでした", "もう一度、上段の ISBN をスキャンしてください。");
                return;
            }

            const bottom = scannedItems.some((item) => this.isPriceCode(item.value));
            this.retryHint = bottom
                ? "それ下段じゃね？ 上段（978 / 979）をスキャンして。"
                : "ISBNじゃないです。上段（978 / 979）をスキャンして。";
            this.toast("warning", bottom ? "それ下段じゃね？" : "ISBNじゃないです", "上段の 978 / 979 を枠に入れてください。");
        } catch (error) {
            if (!error || error.code !== "userDismissedScanner") {
                this.toast("error", "スキャンに失敗しました", error?.message || "もう一度試してください。");
            }
        } finally {
            this.scanning = false;
            await this.safeDismiss();
        }
    }

    buildScanOptions(instructionText) {
        return {
            barcodeTypes: [
                this.scanner.barcodeTypes.EAN_13,
                this.scanner.barcodeTypes.EAN_8,
                this.scanner.barcodeTypes.UPC_A,
                this.scanner.barcodeTypes.UPC_E
            ],
            scannerSize: "XLARGE",
            enableScanLine: true,
            presentWithAnimation: false,
            showSuccessCheckMark: false,
            instructionText,
            successText: instructionText
        };
    }

    isPriceCode(value) {
        return /^19[12]\d{10}$/.test(String(value || "").replace(/\D/g, ""));
    }

    wait(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    async safeDismiss() {
        try {
            if (this.scanner && this.scanner.isAvailable()) {
                await Promise.race([this.scanner.dismiss(), this.wait(800)]);
            }
        } catch (error) {
            // 連続スキャン時に dismiss が失敗しても先へ進む
        }
    }

    toast(variant, title, message) {
        this.dispatchEvent(new ShowToastEvent({ variant, title, message }));
    }

    handleUseIsbn(event) {
        const isbn = event.target.name;
        if (!isbn) {
            return;
        }
        this.dispatchEvent(new CustomEvent("scanresult", { detail: this.buildPayloadFromIsbn(isbn) }));
    }

    publishItems(scannedItems, rawDump) {
        this.rawDump = rawDump;
        this.scannedItems = scannedItems;
        const payload = {
            items: scannedItems,
            rawDump,
            isbn: scannedItems.find((item) => item.isIsbn)?.value
        };
        try {
            sessionStorage.setItem(SCAN_STORAGE_KEY, JSON.stringify(payload));
        } catch (error) {
            // private mode などでは保存できないが、イベントは送る
        }
        this.dispatchEvent(new CustomEvent("scanresult", { detail: payload }));
    }

    buildPayloadFromIsbn(isbn) {
        return {
            items: this.scannedItems,
            rawDump: this.rawDump,
            isbn
        };
    }

    normalizeBarcodes(result, rawDump) {
        const list = Array.isArray(result) ? result : result ? [result] : [];
        const items = list.map((item, index) => this.toScanItem(item, index));
        const missing = items.length === 0 || items.every((item) => !item.value);
        if (missing) {
            return this.itemsFromText(rawDump || this.safeStringify(result));
        }
        return items;
    }

    toScanItem(item, index) {
        const value = this.readValue(item);
        const type = typeof item === "string" ? "(string)" : this.readType(item);
        const kind = this.classify(value);
        return {
            key: `${index}-${value}-${type}`,
            value,
            type: String(type),
            kind,
            isIsbn: kind.startsWith("ISBN"),
            empty: !value
        };
    }

    readValue(item) {
        if (item == null) {
            return "";
        }
        if (typeof item === "string" || typeof item === "number") {
            return String(item);
        }
        const candidates = [item.value, item.barcode, item.text, item.data, item.scannedValue];
        for (const candidate of candidates) {
            if (candidate != null && candidate !== "") {
                return String(candidate);
            }
        }
        return "";
    }

    readType(item) {
        return item?.type || item?.barcodeType || "";
    }

    itemsFromText(text) {
        const matches = String(text || "").match(/\d{8,14}/g) || [];
        return [...new Set(matches)].map((value, index) => {
            const kind = this.classify(value);
            return {
                key: `fallback-${index}-${value}`,
                value,
                type: "(extracted)",
                kind,
                isIsbn: kind.startsWith("ISBN"),
                empty: false
            };
        });
    }

    classify(value) {
        const digits = String(value || "").replace(/\D/g, "");
        if (/^97[89]\d{10}$/.test(digits)) {
            return "ISBN-13（上段の想定）";
        }
        if (/^\d{9}[\dX]$/i.test(String(value || "").replace(/[\s-]/g, ""))) {
            return "ISBN-10";
        }
        if (/^19[12]\d{10}$/.test(digits)) {
            return "日本図書コード（下段・価格）";
        }
        if (digits.length === 5) {
            return "価格アドオン（EAN-5）";
        }
        if (digits.length === 13) {
            return "13桁だが ISBN 接頭辞ではない";
        }
        if (!digits) {
            return "値なし";
        }
        return "ISBN 以外";
    }

    safeStringify(value) {
        try {
            const json = JSON.stringify(value, this.jsonReplacer, 2);
            if (json && json !== "{}" && json !== "[]") {
                return json;
            }
        } catch (error) {
            // host object は stringify できないことがある
        }
        return this.manualDump(value);
    }

    jsonReplacer(key, nested) {
        if (nested && typeof nested === "object" && !Array.isArray(nested)) {
            const extra = {};
            for (const prop of ["value", "type", "barcode", "text", "data"]) {
                try {
                    if (nested[prop] != null && !(prop in nested && Object.prototype.hasOwnProperty.call(nested, prop))) {
                        extra[prop] = nested[prop];
                    }
                } catch (error) {
                    extra[prop] = `(unreadable: ${error.message})`;
                }
            }
            return { ...extra, ...nested };
        }
        return nested;
    }

    manualDump(value) {
        try {
            if (Array.isArray(value)) {
                return JSON.stringify(
                    value.map((item) => ({
                        type: this.readType(item),
                        value: this.readValue(item)
                    })),
                    null,
                    2
                );
            }
            return JSON.stringify(
                { type: this.readType(value), value: this.readValue(value) },
                null,
                2
            );
        } catch (error) {
            return String(value);
        }
    }
}
