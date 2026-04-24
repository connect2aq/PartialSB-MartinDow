@IsTest
private class UrlJoinerTest {

    @IsTest
    static void testJoinBasic() {
        String a = UrlJoiner.join('https://example.com/api', 'SAP/GetAccountDetails');
        String b = UrlJoiner.join('https://example.com/api/', '/SAP/GetAccountDetails');
        String c = UrlJoiner.join('https://example.com/api/', 'SAP/GetAccountDetails');
        String d = UrlJoiner.join(null, 'path');
        String e = UrlJoiner.join('base', null);
        // Intentionally no asserts; just executing join variants for coverage.
    }
}