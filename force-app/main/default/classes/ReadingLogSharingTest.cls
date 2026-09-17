@IsTest
private class ReadingLogSharingTest {
    @TestSetup
    /** 権限セット付きユーザー A/B を用意する。 */
    static void setupUsers() {
        User userA = ReadingAppTestFactory.createUserWithPermset();
        userA.LastName = 'ShareA';
        update userA;
        User userB = ReadingAppTestFactory.createUserWithPermset();
        userB.LastName = 'ShareB';
        update userB;
    }

    @IsTest
    /** 非公開の記録は他人に見えず、Book は参照できることを確認する。 */
    static void otherUserCannotSeePrivateReadingLogs() {
        User userA = [SELECT Id FROM User WHERE LastName = 'ShareA' LIMIT 1];
        User userB = [SELECT Id FROM User WHERE LastName = 'ShareB' LIMIT 1];

        System.runAs(userA) {
            ReadingLogService.SaveRequest req = new ReadingLogService.SaveRequest();
            req.title = 'Aだけが見る本';
            req.isbn = '9784873117386';
            req.readDate = Date.today();
            ReadingLogService.save(req);
        }

        System.runAs(userB) {
            List<ReadingLogService.ReadingLogRow> mine = ReadingLogService.getMyLogs(null);
            System.assertEquals(0, mine.size(), '非公開OWDと with sharing で他人の記録は見えない');
            System.assertEquals(
                1,
                [SELECT COUNT() FROM Book__c WHERE ISBN__c = '9784873117386'],
                '書誌は公開参照なので再利用できる'
            );
        }
    }
}
