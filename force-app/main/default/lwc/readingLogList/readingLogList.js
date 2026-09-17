import { LightningElement, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import LightningConfirm from "lightning/confirm";
import getMyReadingLogs from "@salesforce/apex/BookScannerController.getMyReadingLogs";
import deleteReadingLog from "@salesforce/apex/BookScannerController.deleteReadingLog";

export default class ReadingLogList extends NavigationMixin(LightningElement) {
    keyword = "";
    isLoading = false;
    @track logs = [];

    get isEmpty() {
        return !this.isLoading && this.logs.length === 0;
    }

    connectedCallback() {
        this.loadLogs();
    }

    handleKeywordChange(event) {
        this.keyword = event.target.value;
    }

    handleSearch() {
        this.loadLogs();
    }

    async loadLogs() {
        this.isLoading = true;
        try {
            const data = await getMyReadingLogs({ titleKeyword: this.keyword });
            this.logs = (data || []).map((row) => ({
                ...row,
                hasCover: Boolean(row.coverUrl)
            }));
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "一覧を取得できませんでした",
                    message: error?.body?.message || error?.message,
                    variant: "error"
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleOpen(event) {
        event.preventDefault();
        this.navigateTo(event.currentTarget.dataset.id, "view");
    }

    handleEdit(event) {
        this.navigateTo(event.currentTarget.dataset.id, "edit");
    }

    navigateTo(recordId, actionName) {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId,
                objectApiName: "ReadingLog__c",
                actionName
            }
        });
    }

    async handleDelete(event) {
        const logId = event.currentTarget.dataset.id;
        const confirmed = await LightningConfirm.open({
            message: "この読書記録を削除します。本マスタは残ります。",
            label: "削除の確認",
            theme: "warning"
        });
        if (!confirmed) {
            return;
        }
        try {
            await deleteReadingLog({ logId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "削除しました",
                    variant: "success"
                })
            );
            await this.loadLogs();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: "削除に失敗しました",
                    message: error?.body?.message || error?.message,
                    variant: "error"
                })
            );
        }
    }
}
