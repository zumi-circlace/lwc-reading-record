@IsTest
private class BookScannerControllerTest {
    private class SearchMock implements HttpCalloutMock {
        /** openBD と Google Books をエンドポイントで切り替えて返す。 */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('openbd') || req.getEndpoint().contains('OpenBD') || req.getEndpoint().contains('/v1/get')) {
                res.setBody(
                    '[{"summary":{"isbn":"9780306406157","title":"コントローラ本","author":"A",' +
                    '"publisher":"P","pubdate":"2020","cover":"https://cover.example/c.jpg"}}]'
                );
            } else {
                res.setBody(
                    '{"items":[{"volumeInfo":{"title":"タイトル検索本","authors":["B"],' +
                    '"industryIdentifiers":[{"type":"ISBN_13","identifier":"9784062636940"}]}}]}'
                );
            }
            return res;
        }
    }

    @IsTest
    /** ISBN とタイトルで検索経路が分かれることを確認する。 */
    static void searchBooksRoutesIsbnAndTitle() {
        Test.setMock(HttpCalloutMock.class, new SearchMock());

        Test.startTest();
        BookSearchService.SearchPage isbnPage = BookScannerController.searchBooks(
            '9780306406157',
            0,
            null,
            null
        );
        BookSearchService.SearchPage titlePage = BookScannerController.searchBooks(
            'タイトル検索',
            0,
            '著者B',
            'relevance'
        );
        List<BookInfo> directIsbn = BookScannerController.searchByIsbn('9780306406157');
        Test.stopTest();

        System.assertEquals('コントローラ本', isbnPage.books[0].title);
        System.assertEquals(false, isbnPage.paged);
        System.assertEquals('タイトル検索本', titlePage.books[0].title);
        System.assertEquals(true, titlePage.paged);
        System.assertEquals('コントローラ本', directIsbn[0].title);
    }

    @IsTest
    /** コントローラ経由の保存・一覧・削除が通ることを確認する。 */
    static void saveAndListAndDeleteThroughController() {
        ReadingLogService.SaveRequest req = new ReadingLogService.SaveRequest();
        req.title = 'コントローラ保存';
        req.readDate = Date.today();
        req.isbn = '9784062636940';

        Test.startTest();
        Id logId = BookScannerController.saveReadingLog(req);
        List<ReadingLogService.ReadingLogRow> existing = BookScannerController.findMyLogsForIsbn('9784062636940');
        List<ReadingLogService.ReadingLogRow> listed = BookScannerController.getMyReadingLogs('コントローラ');
        BookScannerController.deleteReadingLog(logId);
        Test.stopTest();

        System.assertEquals(1, existing.size());
        System.assertEquals(1, listed.size());
        System.assertEquals(0, [SELECT COUNT() FROM ReadingLog__c WHERE Id = :logId]);
    }

    @IsTest
    /** バリデーションエラーが AuraHandledException になることを確認する。 */
    static void saveMapsValidationToAuraHandledException() {
        try {
            BookScannerController.saveReadingLog(new ReadingLogService.SaveRequest());
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('必須'));
        }
    }
}
