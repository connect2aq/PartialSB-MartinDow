@IsTest
private class ApiLogUtilTest {

    // English comment: Build a whitespace-heavy blob to trigger \s+ compaction when DEBUG.
    private static String makeWsBlob(Integer targetLen) {
        String unit = 'A   \n\t   B    \r\n';
        String s = '';
        while (s.length() < targetLen) s += unit;
        return s.substring(0, targetLen);
    }

    // English comment: Build a plain string (safe for LTA).
    private static String makePlain(Integer len) {
        String base = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
        String outp = '';
        while (outp.length() < len) outp += base;
        return outp.substring(0, len);
    }

    // ---------- Common: empty flush path ----------
    @IsTest
    static void test_empty_flush() {
        ApiLogUtil.get().clear();
        Test.startTest();
        ApiLogUtil.get().flushSync(); // early return when empty
        Test.stopTest();
        System.debug('size=' + ApiLogUtil.get().size());
    }

    // ---------- Branch 1: CMT missing (no SeeAllData) -> mode is null ----------
    // isTest without SeeAllData simulates: query to CMT fails -> catch -> mode=null -> add() early-return
    @IsTest
    static void test_mode_missing_noSeeAllData() {
        ApiLogUtil.get().clear();

        // Large payloads; but since mode=null, add() returns before buffering anything
        ApiLogUtil.get().add(
            'WhenDisabled',
            makePlain(600),
            'POST',
            makeWsBlob(30000),
            503,
            makeWsBlob(35000)
        );
        ApiLogUtil.get().add('AnotherDisabled','https://x/y','GET',null,200,'{}');

        Test.startTest();
        ApiLogUtil.get().flushSync(); // buffer still empty
        Test.stopTest();

        System.debug('mode missing path executed');
    }

    // ---------- Branch 2: BASIC mode (uses minimal fields) ----------
    @IsTest(SeeAllData=true)
    static void test_basic_mode_minimal_fields() {
        // Try to read mode; if not BASIC, we still run — but true BASIC coverage tabhi max hogi jab org me BASIC ho
        String mode;
        try {
            API_Log_Setup__mdt cfg = [
                SELECT Status__c FROM API_Log_Setup__mdt
                WHERE DeveloperName = 'Decision' LIMIT 1
            ];
            mode = String.valueOf(cfg.Status__c);
        } catch (Exception e) {
            mode = null;
        }

        ApiLogUtil.get().clear();

        // Long URL & name -> trimTo(255) invoked even in BASIC
        String longUrl  = makePlain(600);
        String longName = makePlain(400);

        // Do multiple adds to exercise buffering + minimal field set
        ApiLogUtil.get().add(longName, longUrl, 'POST', makeWsBlob(5000), 500, makeWsBlob(6000));
        ApiLogUtil.get().add('GetPricingBasic', 'https://example.com/SAP/GetMaterialPricingInfo/20251104', 'GET', '{"q":"noop"}', 200, '{"ok":true}');
        ApiLogUtil.get().add(null, '', '', '', 204, '');  // blanks/nulls also safe in BASIC

        Test.startTest();
        ApiLogUtil.get().flushSync();    // insert minimal-field rows
        ApiLogUtil.get().clear();
        // Add more then flush again to hit buffering paths twice
        ApiLogUtil.get().add('AnotherOneBasic', longUrl, 'PATCH', null, 418, '   spaced    out   ');
        ApiLogUtil.get().flushSync();
        Test.stopTest();

        // Read back a few rows (no asserts)
        List<API_Log__c> rows = [
            SELECT Id, API_Name__c, API_URL__c, Request_Method__c, Request_Body__c, Response_Code__c, Response_Message__c
            FROM API_Log__c
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];
        System.debug('BASIC rows size=' + rows.size());
    }

    // ---------- Branch 3: DEBUG probe (optional). If org is BASIC this will still run gracefully but BASIC won’t log full fields. ----------
    @IsTest(SeeAllData=true)
    static void test_debug_probe_chunked_paths_if_enabled() {
        String mode;
        try {
            API_Log_Setup__mdt cfg = [
                SELECT Status__c FROM API_Log_Setup__mdt
                WHERE DeveloperName = 'Decision' LIMIT 1
            ];
            mode = String.valueOf(cfg.Status__c);
        } catch (Exception e) {
            mode = null;
        }

        // Only push heavy DEBUG payloads if mode is not BASIC (i.e., DEBUG). If BASIC, we still do a light call so method executes.
        ApiLogUtil.get().clear();

        if (String.isNotBlank(mode) && mode != 'BASIC') {
            // DEBUG -> exercise concise() + replaceAllInChunks() by sending >20k payloads
            ApiLogUtil.get().add(
                'DebugBigPost',
                makePlain(600),          // trims to 255
                'POST',
                makeWsBlob(50000),       // chunked
                500,
                makeWsBlob(60000)        // chunked
            );
            ApiLogUtil.get().add(
                'DebugSmallGet',
                'https://example.com/ping',
                'GET',
                makeWsBlob(5000),        // small path
                200,
                makeWsBlob(7000)         // small path
            );
        } else {
            // BASIC or null -> do a tiny add so method still executes (will take BASIC/minimal)
            ApiLogUtil.get().add('Ping', 'https://x/p', 'GET', null, 200, '{}');
        }

        Test.startTest();
        ApiLogUtil.get().flushSync();
        Test.stopTest();

        System.debug('debug probe done, mode=' + mode);
    }
}