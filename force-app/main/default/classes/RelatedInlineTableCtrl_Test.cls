@IsTest
public class RelatedInlineTableCtrl_Test {

    // Test data setup once for all tests
    @TestSetup
    static void makeData() {
        List<Account> accs = new List<Account>();
        accs.add(new Account(Name = 'TLG Test 1'));
        accs.add(new Account(Name = 'TLG Test 2'));
        accs.add(new Account(Name = 'TLG Test 3'));
        insert accs;
    }

    @IsTest
    static void test_getRecords_basic_and_defaultLimit() {
        // Happy path with WHERE and explicit limit
        List<Map<String, Object>> rows = RelatedInlineTableCtrl.getRecords(
            'Account',
            new List<String>{ 'Name', 'Phone' },
            'Name LIKE \'TLG%\'',
            10
        );
        // Debug only (no asserts as requested)
        System.debug('getRecords (with where) rows: ' + rows);

        // No WHERE, limit <= 0 to exercise default limit branch
        List<Map<String, Object>> rowsDefault = RelatedInlineTableCtrl.getRecords(
            'Account',
            new List<String>{ 'Name' },
            null,
            0
        );
        System.debug('getRecords (default limit) rows: ' + rowsDefault);
    }

    @IsTest
    static void test_getRecords_relationshipField_throws_is_caught() {
        // Relationship field in field list should trigger the guarded exception path
        try {
            RelatedInlineTableCtrl.getRecords(
                'Account',
                new List<String>{ 'Owner.Name' }, // relationship field (should throw)
                null,
                10
            );
        } catch (Exception e) {
            // Swallow on purpose; we only need to execute the throw branch for coverage
            System.debug('Caught expected exception for relationship field: ' + e.getMessage());
        }
    }

    @IsTest
    static void test_saveRecords_success_and_error_mix() {
        // Query two records to update
        List<Account> accs = [SELECT Id, Name, Type, Phone FROM Account WHERE Name LIKE 'TLG Test %' ORDER BY Name LIMIT 2];
        if (accs.size() < 2) {
            return; // defensive: should not happen in this controlled test
        }

        // Build drafts: one valid, one invalid (restricted picklist)
        List<Map<String, Object>> drafts = new List<Map<String, Object>>();

        Map<String, Object> goodDraft = new Map<String, Object>();
        goodDraft.put('Id', accs[0].Id);
        // Valid picklist value for standard Account.Type (commonly available)
        goodDraft.put('Type', 'Prospect');
        goodDraft.put('Phone', '111-111-1111');
        drafts.add(goodDraft);

        Map<String, Object> badDraft = new Map<String, Object>();
        badDraft.put('Id', accs[1].Id);
        // Invalid picklist value to force a DML error and exercise error branch
        badDraft.put('Type', 'INVALID_OPTION_XYZ');
        drafts.add(badDraft);

        // Call save to execute both success and error paths
        RelatedInlineTableCtrl.SaveResponse resp = RelatedInlineTableCtrl.saveRecords('Account', drafts);
        System.debug('saveRecords response (mixed): ' + resp);
    }

    @IsTest
    static void test_saveRecords_empty_and_null_and_invalid_object() {
        // Empty list => early return
        RelatedInlineTableCtrl.SaveResponse emptyResp = RelatedInlineTableCtrl.saveRecords('Account', new List<Map<String, Object>>());
        System.debug('saveRecords empty drafts: ' + emptyResp);

        // Null drafts => early return
        RelatedInlineTableCtrl.SaveResponse nullResp = RelatedInlineTableCtrl.saveRecords('Account', null);
        System.debug('saveRecords null drafts: ' + nullResp);

        // Invalid objectApiName => invalid object branch, catch to proceed
        try {
            List<Map<String, Object>> dummy = new List<Map<String, Object>>();
            Map<String, Object> m = new Map<String, Object>();
            // Use a fake Id string just to satisfy the method structure; it won't be reached past schema check
            m.put('Id', '001000000000000AAA');
            dummy.add(m);
            RelatedInlineTableCtrl.saveRecords('NopeObject__c', dummy);
        } catch (Exception e) {
            System.debug('Caught expected invalid object exception: ' + e.getMessage());
        }

        // Missing objectApiName => required check branch, catch to proceed
        try {
            RelatedInlineTableCtrl.saveRecords('', new List<Map<String, Object>>());
        } catch (Exception e2) {
            System.debug('Caught expected objectApiName required exception: ' + e2.getMessage());
        }
    }

    @IsTest
    static void test_getRecords_required_checks() {
        // Missing objectApiName => required check, catch and move on
        try {
            RelatedInlineTableCtrl.getRecords('', new List<String>{ 'Name' }, null, 5);
        } catch (Exception e) {
            System.debug('Caught expected objectApiName required exception (getRecords): ' + e.getMessage());
        }

        // Empty field list => required check, catch and move on
        try {
            RelatedInlineTableCtrl.getRecords('Account', new List<String>(), null, 5);
        } catch (Exception e2) {
            System.debug('Caught expected field list required exception (getRecords): ' + e2.getMessage());
        }
    }
}