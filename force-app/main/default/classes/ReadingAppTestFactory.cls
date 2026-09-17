@IsTest
public class ReadingAppTestFactory {
    /** 権限セットなしのテストユーザーを作る。 */
    public static User createUserWithoutPermset() {
        Profile profileRecord = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Minimum Access - Salesforce', 'Standard User')
            ORDER BY Name
            LIMIT 1
        ];
        String stamp = String.valueOf(Datetime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            Alias = stamp.right(8),
            Email = stamp + '@readingapp.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Restricted',
            LanguageLocaleKey = 'ja',
            LocaleSidKey = 'ja_JP',
            ProfileId = profileRecord.Id,
            TimeZoneSidKey = 'Asia/Tokyo',
            Username = stamp + '@readingapp.test'
        );
        insert u;
        return u;
    }

    /** ReadingAppUser を付けたテストユーザーを作る。 */
    public static User createUserWithPermset() {
        User u = createUserWithoutPermset();
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ReadingAppUser' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        return u;
    }
}
