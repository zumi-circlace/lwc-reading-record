@IsTest
private class BookSearchServiceTest {
    private class SearchMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
    /** 指定ステータスとボディを返すコールアウトモック。 */
    SearchMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }
        /** 事前にセットしたステータスとボディを返す。 */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private class StartIndexMock implements HttpCalloutMock {
        String lastEndpoint;
        /** エンドポイントを記録し、1 件の Google Books JSON を返す。 */
        public HTTPResponse respond(HTTPRequest req) {
            lastEndpoint = req.getEndpoint();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"items":[{"volumeInfo":{"title":"2ページ目"}}]}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    @IsTest
    /** openBD のヒット 1 件が BookInfo になることを確認する。 */
    static void searchByIsbnReturnsOpenBdHit() {
        String body =
            '[{"summary":{"isbn":"9780306406157","title":"テスト本","author":"著者A",' +
            '"publisher":"出版社","pubdate":"2018-04","cover":"https://cover.example/x.jpg"}}]';
        Test.setMock(HttpCalloutMock.class, new SearchMock(200, body));

        Test.startTest();
        List<BookInfo> results = BookSearchService.searchByIsbn('978-0-306-40615-7');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('テスト本', results[0].title);
        System.assertEquals('9780306406157', results[0].isbn);
        System.assertEquals('OpenBD', results[0].source);
    }

    @IsTest
    /** openBD が [null] のとき空リストになることを確認する。 */
    static void searchByIsbnReturnsEmptyWhenNullRow() {
        Test.setMock(HttpCalloutMock.class, new SearchMock(200, '[null]'));
        List<BookInfo> results = BookSearchService.searchByIsbn('9780306406157');
        System.assertEquals(0, results.size());
    }

    @IsTest
    /** HTTP 500 で BookSearchException になることを確認する。 */
    static void searchByIsbnThrowsOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new SearchMock(500, 'error'));
        try {
            BookSearchService.searchByIsbn('9780306406157');
            System.assert(false, '例外になるはず');
        } catch (BookSearchException e) {
            System.assert(e.getMessage().contains('500'));
        }
    }

    @IsTest
    /** Google Books の複数フィールドと https 表紙 URL を確認する。 */
    static void searchByTitleParsesGoogleBooksList() {
        String body =
            '{"items":[{"volumeInfo":{"title":"ノルウェイの森","authors":["村上春樹"],' +
            '"publisher":"講談社","publishedDate":"2004","industryIdentifiers":[' +
            '{"type":"ISBN_13","identifier":"9784062636940"}],' +
            '"imageLinks":{"thumbnail":"http://books.google.com/cover.jpg"}}}]}';
        Test.setMock(HttpCalloutMock.class, new SearchMock(200, body));

        Test.startTest();
        List<BookInfo> results = BookSearchService.searchByTitle('ノルウェイの森');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('ノルウェイの森', results[0].title);
        System.assertEquals('村上春樹', results[0].author);
        System.assertEquals('9784062636940', results[0].isbn);
        System.assertEquals('https://books.google.com/cover.jpg', results[0].coverUrl);
        System.assertEquals('GoogleBooks', results[0].source);
    }

    @IsTest
    /** startIndex・著者・並び順が Google Books のクエリに載ることを確認する。 */
    static void searchByTitleSendsStartIndex() {
        StartIndexMock mock = new StartIndexMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        BookSearchService.SearchPage page = BookSearchService.searchByTitle('ページング', 20, '村上', 'newest');
        Test.stopTest();

        System.assert(mock.lastEndpoint.contains('startIndex=20'), mock.lastEndpoint);
        System.assert(mock.lastEndpoint.contains('inauthor'), mock.lastEndpoint);
        System.assert(mock.lastEndpoint.contains('orderBy=newest'), mock.lastEndpoint);
        System.assertEquals(true, page.paged);
        System.assertEquals(true, page.hasPrevious);
        System.assertEquals(20, page.startIndex);
        System.assertEquals(false, page.hasNext);
    }

    @IsTest
    /** items が無いレスポンスは 0 件になることを確認する。 */
    static void searchByTitleEmptyItems() {
        Test.setMock(HttpCalloutMock.class, new SearchMock(200, '{"totalItems":0}'));
        System.assertEquals(0, BookSearchService.searchByTitle('存在しない本XYZ').size());
    }

    @IsTest
    /** 不正 ISBN・空タイトルで例外になることを確認する。 */
    static void blankInputsThrow() {
        try {
            BookSearchService.searchByIsbn('abc');
            System.assert(false);
        } catch (BookSearchException e) {
            System.assert(e.getMessage().contains('ISBN'));
        }
        try {
            BookSearchService.searchByTitle('  ');
            System.assert(false);
        } catch (BookSearchException e) {
            System.assert(e.getMessage().contains('タイトル'));
        }
    }
}
