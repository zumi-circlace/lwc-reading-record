/** LWC から呼ばれる入口。例外は AuraHandledException に変換する。 */
public with sharing class BookScannerController {
    /** ISBN なら openBD、それ以外はタイトル／著者検索に振り分ける。 */
    @AuraEnabled(cacheable=false)
    public static BookSearchService.SearchPage searchBooks(
        String query,
        Integer startIndex,
        String author,
        String orderBy
    ) {
        try {
            if (IsbnUtil.isIsbnQuery(query)) {
                BookSearchService.SearchPage page = new BookSearchService.SearchPage();
                page.books = BookSearchService.searchByIsbn(query);
                page.startIndex = 0;
                page.paged = false;
                page.hasNext = false;
                page.hasPrevious = false;
                return page;
            }
            return BookSearchService.searchByTitle(query, startIndex, author, orderBy);
        } catch (BookSearchException e) {
            throw auraError(e.getMessage());
        } catch (Exception e) {
            throw auraError('検索に失敗しました: ' + e.getMessage());
        }
    }

    /** カメラ／ISBN 専用。openBD で書誌を取得する。 */
    @AuraEnabled(cacheable=false)
    public static List<BookInfo> searchByIsbn(String isbn) {
        try {
            return BookSearchService.searchByIsbn(isbn);
        } catch (BookSearchException e) {
            throw auraError(e.getMessage());
        } catch (Exception e) {
            throw auraError('ISBN検索に失敗しました: ' + e.getMessage());
        }
    }

    /** 同じ ISBN に対する自分の既存記録を返す。 */
    @AuraEnabled(cacheable=false)
    public static List<ReadingLogService.ReadingLogRow> findMyLogsForIsbn(String isbn) {
        try {
            return ReadingLogService.findMyLogsForIsbn(isbn);
        } catch (Exception e) {
            throw auraError('既存記録の確認に失敗しました: ' + e.getMessage());
        }
    }

    /** 確認画面の内容で Book と ReadingLog を保存する。 */
    @AuraEnabled(cacheable=false)
    public static Id saveReadingLog(ReadingLogService.SaveRequest request) {
        try {
            return ReadingLogService.save(request);
        } catch (BookSearchException e) {
            throw auraError(e.getMessage());
        } catch (Exception e) {
            throw auraError('保存に失敗しました: ' + e.getMessage());
        }
    }

    /** 自分の記録一覧を返す。 */
    @AuraEnabled(cacheable=false)
    public static List<ReadingLogService.ReadingLogRow> getMyReadingLogs(String titleKeyword) {
        try {
            return ReadingLogService.getMyLogs(titleKeyword);
        } catch (Exception e) {
            throw auraError('一覧の取得に失敗しました: ' + e.getMessage());
        }
    }

    /** 指定した読書記録を削除する。 */
    @AuraEnabled(cacheable=false)
    public static void deleteReadingLog(Id logId) {
        try {
            ReadingLogService.deleteLog(logId);
        } catch (BookSearchException e) {
            throw auraError(e.getMessage());
        } catch (Exception e) {
            throw auraError('削除に失敗しました: ' + e.getMessage());
        }
    }

    /** LWC に見せるメッセージ付き AuraHandledException を作る。 */
    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
