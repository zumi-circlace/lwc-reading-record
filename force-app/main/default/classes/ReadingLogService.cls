/** Book の find-or-create と ReadingLog の CRUD。DML/SOQL は USER_MODE。 */
public inherited sharing class ReadingLogService {
    /** LWC 確認画面から渡す保存内容。 */
    public class SaveRequest {
        @AuraEnabled public String bookId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String isbn { get; set; }
        @AuraEnabled public String author { get; set; }
        @AuraEnabled public String publisher { get; set; }
        @AuraEnabled public String publishedYear { get; set; }
        @AuraEnabled public String coverUrl { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public Date readDate { get; set; }
        @AuraEnabled public String description { get; set; }
    }

    /** 一覧・再読警告用の 1 行。 */
    public class ReadingLogRow {
        @AuraEnabled public Id logId { get; set; }
        @AuraEnabled public Id bookId { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String isbn { get; set; }
        @AuraEnabled public String author { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String coverUrl { get; set; }
        @AuraEnabled public Date readDate { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String displayName { get; set; }
    }

    /** Book を find-or-create し、ReadingLog を USER_MODE で insert する。 */
    public static Id save(SaveRequest req) {
        if (req == null || String.isBlank(req.title) || req.readDate == null) {
            throw new BookSearchException('タイトルと読了日は必須です。');
        }

        String isbn = IsbnUtil.normalize(req.isbn);
        Book__c book = findBook(isbn, req.bookId);

        if (book == null) {
            book = new Book__c();
            applyBookFields(book, req, isbn);
            insert as user book;
        } else if (book.OwnerId == UserInfo.getUserId()) {
            applyBookFields(book, req, isbn);
            update as user book;
        }

        ReadingLog__c logRecord = new ReadingLog__c(
            Book__c = book.Id,
            ReadDate__c = req.readDate,
            Description__c = req.description
        );
        insert as user logRecord;
        return logRecord.Id;
    }

    /** 指定 ISBN の本に紐づく、自分の既存記録を返す（再読警告用）。 */
    public static List<ReadingLogRow> findMyLogsForIsbn(String rawIsbn) {
        String isbn = IsbnUtil.normalize(rawIsbn);
        if (String.isBlank(isbn)) {
            return new List<ReadingLogRow>();
        }
        List<Book__c> books = [
            SELECT Id
            FROM Book__c
            WHERE ISBN__c = :isbn
            WITH USER_MODE
            LIMIT 1
        ];
        if (books.isEmpty()) {
            return new List<ReadingLogRow>();
        }
        return queryMyLogs(books[0].Id, null);
    }

    /** 自分の記録を読了日降順で返す。titleKeyword があればタイトル部分一致。 */
    public static List<ReadingLogRow> getMyLogs(String titleKeyword) {
        return queryMyLogs(null, titleKeyword);
    }

    /** 自分の読書記録を 1 件削除する。Book は消さない。 */
    public static void deleteLog(Id logId) {
        if (logId == null) {
            throw new BookSearchException('削除対象が指定されていません。');
        }
        List<ReadingLog__c> logs = [
            SELECT Id
            FROM ReadingLog__c
            WHERE Id = :logId
            WITH USER_MODE
            LIMIT 1
        ];
        if (logs.isEmpty()) {
            throw new BookSearchException('記録が見つからないか、削除する権限がありません。');
        }
        delete as user logs;
    }

    /** Id または ISBN で既存の Book を探す。無ければ null。 */
    private static Book__c findBook(String isbn, String bookId) {
        if (String.isNotBlank(bookId)) {
            List<Book__c> byId = [
                SELECT
                    Id,
                    Title__c,
                    ISBN__c,
                    Author__c,
                    Publisher__c,
                    PublishedYear__c,
                    CoverUrl__c,
                    Category__c,
                    OwnerId
                FROM Book__c
                WHERE Id = :bookId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!byId.isEmpty()) {
                return byId[0];
            }
        }
        if (String.isBlank(isbn)) {
            return null;
        }
        List<Book__c> byIsbn = [
            SELECT
                Id,
                Title__c,
                ISBN__c,
                Author__c,
                Publisher__c,
                PublishedYear__c,
                CoverUrl__c,
                Category__c,
                OwnerId
            FROM Book__c
            WHERE ISBN__c = :isbn
            WITH USER_MODE
            LIMIT 1
        ];
        return byIsbn.isEmpty() ? null : byIsbn[0];
    }

    /** 確認画面の入力を Book 項目へコピーする。 */
    private static void applyBookFields(Book__c book, SaveRequest req, String isbn) {
        book.Title__c = req.title;
        book.ISBN__c = isbn;
        book.Author__c = req.author;
        book.Publisher__c = req.publisher;
        book.PublishedYear__c = req.publishedYear;
        book.CoverUrl__c = req.coverUrl;
        book.Category__c = req.category;
    }

    /** 自分の ReadingLog を USER_MODE で取得し、行 DTO に変換する。 */
    private static List<ReadingLogRow> queryMyLogs(Id bookId, String titleKeyword) {
        String likeKey;
        if (String.isNotBlank(titleKeyword)) {
            likeKey = '%' + titleKeyword.trim() + '%';
        }

        String soql =
            'SELECT Id, Book__c, ReadDate__c, Description__c, DisplayName__c, ' +
            'Book__r.Title__c, Book__r.ISBN__c, Book__r.Author__c, ' +
            'Book__r.Category__c, Book__r.CoverUrl__c ' +
            'FROM ReadingLog__c ' +
            'WHERE OwnerId = :ownerId ';
        Id ownerId = UserInfo.getUserId();
        if (bookId != null) {
            soql += 'AND Book__c = :bookId ';
        }
        if (likeKey != null) {
            soql += 'AND Book__r.Title__c LIKE :likeKey ';
        }
        soql += 'WITH USER_MODE ORDER BY ReadDate__c DESC NULLS LAST LIMIT 200';

        List<ReadingLogRow> rows = new List<ReadingLogRow>();
        for (ReadingLog__c rec : Database.query(soql)) {
            ReadingLogRow row = new ReadingLogRow();
            row.logId = rec.Id;
            row.bookId = rec.Book__c;
            row.readDate = rec.ReadDate__c;
            row.description = rec.Description__c;
            row.displayName = rec.DisplayName__c;
            row.title = rec.Book__r.Title__c;
            row.isbn = rec.Book__r.ISBN__c;
            row.author = rec.Book__r.Author__c;
            row.category = rec.Book__r.Category__c;
            row.coverUrl = rec.Book__r.CoverUrl__c;
            rows.add(row);
        }
        return rows;
    }
}
