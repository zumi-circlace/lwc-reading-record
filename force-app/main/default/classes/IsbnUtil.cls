/**
 * ISBN-10 / ISBN-13 の正規化。検索キーは常にハイフンなし ISBN-13 にする。
 */
public inherited sharing class IsbnUtil {
    /** 入力が ISBN（10 or 13）かどうかを判定する。 */
    public static Boolean isIsbnQuery(String raw) {
        if (String.isBlank(raw)) {
            return false;
        }
        String compact = compact(raw);
        return isIsbn10(compact) || isIsbn13(compact);
    }

    /** ハイフンを除き、ISBN-10 なら 13 に変換して返す。不正なら null。 */
    public static String normalize(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String compact = compact(raw);
        if (isIsbn13(compact)) {
            return compact;
        }
        if (isIsbn10(compact)) {
            return toIsbn13(compact);
        }
        String digits = compact.replaceAll('[^0-9]', '');
        if (digits.length() == 13) {
            return digits;
        }
        return null;
    }

    /** 空白とハイフンを除去して大文字にする。 */
    @TestVisible
    private static String compact(String raw) {
        return raw.trim().replaceAll('[\\s-]', '').toUpperCase();
    }

    /** 13桁の数字なら ISBN-13 とみなす。 */
    private static Boolean isIsbn13(String compact) {
        return Pattern.matches('^[0-9]{13}$', compact);
    }

    /** 9桁+チェック桁（数字または X）なら ISBN-10 とみなす。 */
    private static Boolean isIsbn10(String compact) {
        return Pattern.matches('^[0-9]{9}[0-9X]$', compact);
    }

    /** ISBN-10 の本体9桁に 978 を付け、チェック桁を再計算して ISBN-13 にする。 */
    @TestVisible
    private static String toIsbn13(String isbn10) {
        String core = '978' + isbn10.substring(0, 9);
        Integer sum = 0;
        for (Integer i = 0; i < 12; i++) {
            Integer digit = Integer.valueOf(core.substring(i, i + 1));
            sum += Math.mod(i, 2) == 0 ? digit : digit * 3;
        }
        Integer check = Math.mod(10 - Math.mod(sum, 10), 10);
        return core + String.valueOf(check);
    }
}
