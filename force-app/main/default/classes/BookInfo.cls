/** LWC と Apex の間でやり取りする書誌の入れ物。 */
public class BookInfo {
    @AuraEnabled public String bookId;
    @AuraEnabled public String title;
    @AuraEnabled public String isbn;
    @AuraEnabled public String author;
    @AuraEnabled public String publisher;
    @AuraEnabled public String publishedYear;
    @AuraEnabled public String coverUrl;
    @AuraEnabled public String category;
    @AuraEnabled public String source;
}
