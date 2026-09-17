@IsTest
private class IsbnUtilTest {
    @IsTest
    /** ISBN-13（ハイフン付き）が正規化後も 13 のままであることを確認する。 */
    static void isbn13StaysIsbn13() {
        System.assertEquals('9780306406157', IsbnUtil.normalize('978-0-306-40615-7'));
        System.assertEquals(true, IsbnUtil.isIsbnQuery('9780306406157'));
    }

    @IsTest
    /** ISBN-10 が 978 付き ISBN-13 に変換されることを確認する。 */
    static void isbn10ConvertsToIsbn13() {
        System.assertEquals('9780306406157', IsbnUtil.normalize('0-306-40615-2'));
        System.assertEquals('9780306406157', IsbnUtil.normalize('0306406152'));
        System.assertEquals(true, IsbnUtil.isIsbnQuery('0306406152'));
    }

    @IsTest
    /** 空文字・タイトル・短い数字は ISBN とみなさない。 */
    static void blankAndTitleAreNotIsbn() {
        System.assertEquals(null, IsbnUtil.normalize(''));
        System.assertEquals(null, IsbnUtil.normalize(null));
        System.assertEquals(false, IsbnUtil.isIsbnQuery('ノルウェイの森'));
        System.assertEquals(false, IsbnUtil.isIsbnQuery('12345'));
    }
}
