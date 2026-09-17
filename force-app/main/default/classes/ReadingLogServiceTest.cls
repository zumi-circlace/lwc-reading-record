@IsTest
private class ReadingLogServiceTest {
    @TestSetup
    /** 既存の Book と ReadingLog を 1 件ずつ用意する。 */
    static void setupData() {
        Book__c book = new Book__c(
            Title__c = '共有される本',
            ISBN__c = '9780306406157',
            Author__c = '著者',
            Category__c = '小説'
        );
        insert book;
        insert new ReadingLog__c(Book__c = book.Id, ReadDate__c = Date.today(), Description__c = '初読');
    }

    @IsTest
    /** 未知の ISBN なら新しい Book と Log を作る。 */
    static void saveCreatesBookAndLogWhenIsbnIsNew() {
        ReadingLogService.SaveRequest req = newRequest('新しい本', '9784062636940', Date.today());

        Test.startTest();
        Id logId = ReadingLogService.save(req);
        Test.stopTest();

        ReadingLog__c saved = [
            SELECT Book__c, Book__r.ISBN__c, Book__r.Title__c, ReadDate__c
            FROM ReadingLog__c
            WHERE Id = :logId
        ];
        System.assertEquals('9784062636940', saved.Book__r.ISBN__c);
        System.assertEquals('新しい本', saved.Book__r.Title__c);
    }

    @IsTest
    /** 既存 ISBN の Book を再利用して Log だけ増やす。 */
    static void saveReusesExistingBookByIsbn() {
        Id originalBookId = [SELECT Id FROM Book__c WHERE ISBN__c = '9780306406157'].Id;
        ReadingLogService.SaveRequest req = newRequest('共有される本', '978-0-306-40615-7', Date.today().addDays(-1));

        Test.startTest();
        Id logId = ReadingLogService.save(req);
        Test.stopTest();

        ReadingLog__c saved = [SELECT Book__c FROM ReadingLog__c WHERE Id = :logId];
        System.assertEquals(originalBookId, saved.Book__c);
        System.assertEquals(2, [SELECT COUNT() FROM ReadingLog__c WHERE Book__c = :originalBookId]);
    }

    @IsTest
    /** ISBN なし手打ちは毎回新しい Book になる。 */
    static void saveWithoutIsbnAlwaysInsertsNewBook() {
        ReadingLogService.SaveRequest first = newRequest('同人誌', null, Date.today());
        ReadingLogService.SaveRequest second = newRequest('同人誌', null, Date.today());

        ReadingLogService.save(first);
        ReadingLogService.save(second);

        System.assertEquals(2, [SELECT COUNT() FROM Book__c WHERE Title__c = '同人誌' AND ISBN__c = null]);
    }

    @IsTest
    /** タイトルと読了日が無いと保存できない。 */
    static void saveRequiresTitleAndDate() {
        ReadingLogService.SaveRequest req = new ReadingLogService.SaveRequest();
        try {
            ReadingLogService.save(req);
            System.assert(false);
        } catch (BookSearchException e) {
            System.assert(e.getMessage().contains('必須'));
        }
    }

    @IsTest
    /** ISBN から自分の既存記録が引ける。 */
    static void findMyLogsForIsbnReturnsOwnLogs() {
        List<ReadingLogService.ReadingLogRow> rows = ReadingLogService.findMyLogsForIsbn('9780306406157');
        System.assertEquals(1, rows.size());
        System.assertEquals('共有される本', rows[0].title);
    }

    @IsTest
    /** タイトルキーワードで一覧が絞り込まれる。 */
    static void getMyLogsFiltersByTitle() {
        System.assertEquals(1, ReadingLogService.getMyLogs('共有').size());
        System.assertEquals(0, ReadingLogService.getMyLogs('存在しないタイトル').size());
    }

    @IsTest
    /** Log 削除後も Book は残る。 */
    static void deleteLogRemovesReadingLogOnly() {
        Id logId = [SELECT Id FROM ReadingLog__c LIMIT 1].Id;
        ReadingLogService.deleteLog(logId);
        System.assertEquals(0, [SELECT COUNT() FROM ReadingLog__c]);
        System.assertEquals(1, [SELECT COUNT() FROM Book__c]);
    }

    @IsTest
    /** オブジェクト権限が無いユーザーは USER_MODE で insert できない。 */
    static void userModeBlocksInsertWithoutObjectAccess() {
        User restricted = ReadingAppTestFactory.createUserWithoutPermset();
        ReadingLogService.SaveRequest req = newRequest('権限なし', null, Date.today());
        System.runAs(restricted) {
            try {
                ReadingLogService.save(req);
                System.assert(false, 'USER_MODE で失敗するはず');
            } catch (Exception e) {
                System.assert(e instanceof System.SecurityException || e.getMessage() != null);
            }
        }
    }

    /** テスト用の SaveRequest を組み立てる。 */
    private static ReadingLogService.SaveRequest newRequest(String title, String isbn, Date readDate) {
        ReadingLogService.SaveRequest req = new ReadingLogService.SaveRequest();
        req.title = title;
        req.isbn = isbn;
        req.readDate = readDate;
        req.category = '小説';
        return req;
    }
}
