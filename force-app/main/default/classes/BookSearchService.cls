/**
 * openBD（ISBN）と Google Books（タイトル）へのコールアウト。
 * エンドポイントは Named Credential 経由にし、ホストをソースに直書きしない。
 */
public inherited sharing class BookSearchService {
    private static final Integer TIMEOUT_MS = 12000;
    private static final Integer TITLE_LIMIT = 10;

    /** ISBN を正規化し、openBD で書誌を 0〜1 件取得する。 */
    public static List<BookInfo> searchByIsbn(String rawIsbn) {
        String isbn = IsbnUtil.normalize(rawIsbn);
        if (String.isBlank(isbn)) {
            throw new BookSearchException('ISBNの形式を確認してください。');
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setTimeout(TIMEOUT_MS);
        req.setEndpoint('callout:OpenBD/v1/get?isbn=' + EncodingUtil.urlEncode(isbn, 'UTF-8'));

        HttpResponse res = send(req);
        return parseOpenBd(res.getBody());
    }

    /** タイトルで Google Books を検索し、最大 10 件返す。 */
    public static List<BookInfo> searchByTitle(String title) {
        if (String.isBlank(title)) {
            throw new BookSearchException('タイトルを入力してください。');
        }

        String endpoint =
            'callout:GoogleBooks/books/v1/volumes?q=' +
            EncodingUtil.urlEncode(title.trim(), 'UTF-8') +
            '&maxResults=' +
            TITLE_LIMIT +
            '&printType=books';
        String apiKey = googleBooksApiKey();
        if (String.isNotBlank(apiKey)) {
            endpoint += '&key=' + EncodingUtil.urlEncode(apiKey, 'UTF-8');
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setTimeout(TIMEOUT_MS);
        req.setEndpoint(endpoint);

        HttpResponse res = send(req);
        return parseGoogleBooks(res.getBody());
    }

    /** HTTP を送り、通信失敗や 2xx 以外は BookSearchException にする。 */
    private static HttpResponse send(HttpRequest req) {
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception e) {
            throw new BookSearchException('書誌APIへの接続に失敗しました: ' + e.getMessage());
        }
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new BookSearchException('書誌APIがエラーを返しました（' + res.getStatusCode() + '）。');
        }
        return res;
    }

    /** Custom Metadata から Google Books の API キーを読む。無ければ null。 */
    private static String googleBooksApiKey() {
        List<Api_Setting__mdt> settings = [
            SELECT ApiKey__c
            FROM Api_Setting__mdt
            WHERE DeveloperName = 'Google_Books'
            LIMIT 1
        ];
        if (settings.isEmpty()) {
            return null;
        }
        return settings[0].ApiKey__c;
    }

    /** openBD の JSON 配列を BookInfo に変換する。 */
    @TestVisible
    private static List<BookInfo> parseOpenBd(String body) {
        List<BookInfo> results = new List<BookInfo>();
        if (String.isBlank(body) || body.trim() == 'null') {
            return results;
        }
        Object untyped = JSON.deserializeUntyped(body);
        if (!(untyped instanceof List<Object>)) {
            return results;
        }
        for (Object row : (List<Object>) untyped) {
            if (row == null || !(row instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> root = (Map<String, Object>) row;
            Map<String, Object> summary = (Map<String, Object>) root.get('summary');
            if (summary == null) {
                continue;
            }
            BookInfo info = new BookInfo();
            info.title = textValue(summary.get('title'));
            info.isbn = IsbnUtil.normalize(textValue(summary.get('isbn')));
            info.author = textValue(summary.get('author'));
            info.publisher = textValue(summary.get('publisher'));
            info.publishedYear = textValue(summary.get('pubdate'));
            info.coverUrl = httpsUrl(textValue(summary.get('cover')));
            info.source = 'OpenBD';
            if (String.isNotBlank(info.title)) {
                results.add(info);
            }
        }
        return results;
    }

    /** Google Books の volumes JSON を BookInfo リストに変換する。 */
    @TestVisible
    private static List<BookInfo> parseGoogleBooks(String body) {
        List<BookInfo> results = new List<BookInfo>();
        if (String.isBlank(body)) {
            return results;
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> items = (List<Object>) root.get('items');
        if (items == null) {
            return results;
        }
        for (Object itemObj : items) {
            Map<String, Object> item = (Map<String, Object>) itemObj;
            Map<String, Object> volume = (Map<String, Object>) item.get('volumeInfo');
            if (volume == null) {
                continue;
            }
            BookInfo info = new BookInfo();
            info.title = textValue(volume.get('title'));
            info.author = joinList(volume.get('authors'));
            info.publisher = textValue(volume.get('publisher'));
            info.publishedYear = textValue(volume.get('publishedDate'));
            info.isbn = extractIsbn13(volume.get('industryIdentifiers'));
            Map<String, Object> images = (Map<String, Object>) volume.get('imageLinks');
            if (images != null) {
                String thumb = textValue(images.get('thumbnail'));
                if (String.isBlank(thumb)) {
                    thumb = textValue(images.get('smallThumbnail'));
                }
                info.coverUrl = httpsUrl(thumb);
            }
            info.source = 'GoogleBooks';
            if (String.isNotBlank(info.title)) {
                results.add(info);
            }
        }
        return results;
    }

    /** industryIdentifiers から ISBN-13 を優先して取り出す。 */
    private static String extractIsbn13(Object identifiersObj) {
        if (!(identifiersObj instanceof List<Object>)) {
            return null;
        }
        String isbn10;
        for (Object idObj : (List<Object>) identifiersObj) {
            Map<String, Object> idMap = (Map<String, Object>) idObj;
            String typeName = textValue(idMap.get('type'));
            String identifier = textValue(idMap.get('identifier'));
            if (typeName == 'ISBN_13') {
                return IsbnUtil.normalize(identifier);
            }
            if (typeName == 'ISBN_10') {
                isbn10 = identifier;
            }
        }
        return IsbnUtil.normalize(isbn10);
    }

    /** JSON の配列をカンマ区切り文字にする。 */
    private static String joinList(Object value) {
        if (!(value instanceof List<Object>)) {
            return textValue(value);
        }
        List<String> parts = new List<String>();
        for (Object part : (List<Object>) value) {
            String text = textValue(part);
            if (String.isNotBlank(text)) {
                parts.add(text);
            }
        }
        return String.join(parts, ', ');
    }

    /** JSON 値を文字列にする。null はそのまま。 */
    private static String textValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    /** 表紙 URL を https に揃える。 */
    private static String httpsUrl(String url) {
        if (String.isBlank(url)) {
            return null;
        }
        if (url.startsWith('http://')) {
            return 'https://' + url.substring(7);
        }
        return url;
    }
}
