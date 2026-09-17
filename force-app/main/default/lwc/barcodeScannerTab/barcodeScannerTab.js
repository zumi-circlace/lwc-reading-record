import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getBarcodeScanner } from "lightning/mobileCapabilities";

export default class BarcodeScannerTab extends LightningElement {
    scanner;
    scanning = false;

    get scannerAvailable() {
        return this.scanner && this.scanner.isAvailable();
    }

    connectedCallback() {
        this.scanner = getBarcodeScanner();
    }

    async handleScan() {
        if (!this.scannerAvailable) {
            return;
        }
        this.scanning = true;
        try {
            const result = await this.scanner.scan({
                barcodeTypes: [
                    this.scanner.barcodeTypes.EAN_13,
                    this.scanner.barcodeTypes.EAN_8,
                    this.scanner.barcodeTypes.UPC_A,
                    this.scanner.barcodeTypes.UPC_E
                ],
                instructionText: "本のバーコードを枠に入れてください",
                successText: "読み取りました"
            });
            const isbn = result?.value;
            if (isbn) {
                this.dispatchEvent(new CustomEvent("isbnscanned", { detail: { isbn } }));
            }
        } catch (error) {
            if (error && error.code !== "userDismissedScanner") {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: "スキャンに失敗しました",
                        message: error.message || "もう一度試してください。",
                        variant: "error"
                    })
                );
            }
        } finally {
            this.scanning = false;
            if (this.scanner && this.scanner.isAvailable()) {
                await this.scanner.dismiss();
            }
        }
    }
}
