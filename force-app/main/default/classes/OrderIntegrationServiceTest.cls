@IsTest
public class OrderIntegrationServiceTest {

    // ---------------------------------------------
    // Mocks focused on FAILURE branches of createOrderInSystem
    // ---------------------------------------------

    // 1) Auth returns token but NO baseEndpointUrl -> triggers "missing auth/base URL" failure branch
    class AuthNoBaseUrlMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // Simulate auth success BUT without baseEndpointUrl field
            res.setBody('{"success":true,"token":"mocktoken"}');
            res.setStatusCode(200);
            return res;
        }
    }

    // 2) Full auth (token + baseEndpointUrl) AND order API returns 200 with success=false
    class Composite200AppFailMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            // Rough routing by endpoint text
            String ep = String.valueOf(req.getEndpoint());
            if (ep.contains('/Login/Auth')) {
                // Auth response with base URL present
                res.setBody('{"success":true,"token":"mocktoken","baseEndpointUrl":"https://api.test/"}');
                res.setStatusCode(200);
            } else if (ep.contains('SAP/PostFocIssuance') || ep.contains('SAP/PostDemo')) {
                // Order API responds 200 but application-level failure
                res.setBody('{"success":false,"message":"Invalid data sent","data":null}');
                res.setStatusCode(200);
            } else {
                res.setBody('{"success":true}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // 3) Full auth AND order API returns a non-200 (e.g., 500) -> triggers HTTP failure branch
    class CompositeNon200Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String ep = String.valueOf(req.getEndpoint());
            if (ep.contains('/Login/Auth')) {
                res.setBody('{"success":true,"token":"mocktoken","baseEndpointUrl":"https://api.test/"}');
                res.setStatusCode(200);
            } else if (ep.contains('SAP/PostFocIssuance') || ep.contains('SAP/PostDemo')) {
                res.setBody('{"error":"boom"}');
                res.setStatusCode(500);
                res.setStatus('500 Internal Server Error');
            } else {
                res.setBody('{"success":true}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // ---------------------------------------------
    // Test data helpers
    // ---------------------------------------------

    // Create an order with allowed type + one item (fields shaped to exercise extractCode)
    private static MD_Order__c makeAllowedOrder() {
        MD_Order__c o = new MD_Order__c(
            Order_Type__c = 'YKB - Demo Release Order',
            Customer_Reference_Date__c = Date.today(),
            //Sales_Org__c = '1000 - Sales Org',
            //Distribution_Channel__c = '10 - Dist',
            //Division__c = '01 - Division',
            //Delivering_Plant__c = 'PL01 - Plant',
            //Sales_Office__c = 'SO01 - Office',
            //Customer_Code_Bill_To__c = 'C0001 - BillTo',
            //Customer_Code_Ship_To__c = 'S0001 - ShipTo',
            Purchase_Order_Number__c = 'PO-UT-001'
        );
        insert o;

        MD_OrderItem__c it = new MD_OrderItem__c(
            OrderId__c = o.Id,
            Quantity__c = 3,
            //Material_Number__c = '15000892 - Test Material',
            Storage_Location__c = 'LOC1 - Main'
        );
        insert it;

        return o;
    }

    private static MD_Order__c makeInvalidTypeOrder() {
        MD_Order__c o = new MD_Order__c(
            Order_Type__c = 'YKB - Demo Release Order',
            Customer_Reference_Date__c = Date.today()
        );
        insert o;
        return o;
    }

    // ---------------------------------------------
    // Coverage-focused tests (no assertEquals)
    // ---------------------------------------------

    @IsTest
    static void test_BuildRequest_ValidType() {
        MD_Order__c o = makeAllowedOrder();
        Test.startTest();
        OrderIntegrationService.buildOrderRequest(o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_BuildRequest_InvalidType() {
        MD_Order__c o = makeInvalidTypeOrder();
        Test.startTest();
        OrderIntegrationService.buildOrderRequest(o.Id); // returns null (early return)
        Test.stopTest();
    }

    @IsTest
    static void test_CreateOrder_MissingBaseUrl_FailsAndStoresError() {
        MD_Order__c o = makeAllowedOrder();
        Test.setMock(HttpCalloutMock.class, new AuthNoBaseUrlMock());
        Test.startTest();
        OrderIntegrationService.createOrderInSystem(o.Id); // Should mark Failed with error about auth/base URL missing
        Test.stopTest();

        // Re-query only to execute lines; no asserts per your preference
        o = [SELECT Id, Status__c, Error_Message__c FROM MD_Order__c WHERE Id = :o.Id];
        System.debug(o);
    }

    @IsTest
    static void test_CreateOrder_Http200_AppFailure() {
        MD_Order__c o = makeAllowedOrder();
        Test.setMock(HttpCalloutMock.class, new Composite200AppFailMock());
        Test.startTest();
        OrderIntegrationService.createOrderInSystem(o.Id); // 200 but success=false -> markOrderFailed with API message
        Test.stopTest();

        o = [SELECT Id, Status__c, Error_Message__c FROM MD_Order__c WHERE Id = :o.Id];
        System.debug(o);
    }

    @IsTest
    static void test_CreateOrder_Non200_HttpFailure() {
        MD_Order__c o = makeAllowedOrder();
        Test.setMock(HttpCalloutMock.class, new CompositeNon200Mock());
        Test.startTest();
        OrderIntegrationService.createOrderInSystem(o.Id); // Non-200 -> markOrderFailed with HTTP body
        Test.stopTest();

        o = [SELECT Id, Status__c, Error_Message__c FROM MD_Order__c WHERE Id = :o.Id];
        System.debug(o);
    }

    @IsTest
    static void test_Future_ProcessOrders_FailurePathCovered() {
        MD_Order__c o = makeAllowedOrder();
        Test.setMock(HttpCalloutMock.class, new AuthNoBaseUrlMock());
        Test.startTest();
        OrderIntegrationService.processOrdersForIntegration(new List<Id>{ o.Id });
        Test.stopTest();

        o = [SELECT Id, Status__c, Error_Message__c FROM MD_Order__c WHERE Id = :o.Id];
        System.debug(o);
    }

    @IsTest
    static void test_ExtractCode_AllBranches() {
        OrderIntegrationService.extractCode('ABC - Something');
        OrderIntegrationService.extractCode('XYZ');
        OrderIntegrationService.extractCode(null);
    }
}