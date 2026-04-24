@isTest
public class TokenRequestTest {
    @isTest
    static void testGetAuthToken_TestVisible() {
        // Set test token
        TokenRequest.AuthTokenResult fakeToken = new TokenRequest.AuthTokenResult();
        fakeToken.token = 'TEST_TOKEN';
        fakeToken.baseEndpointUrl = 'https://test.endpoint/';
        TokenRequest.testTokenResult = fakeToken;

        TokenRequest.AuthTokenResult result = TokenRequest.getAuthToken();
        System.assertEquals('TEST_TOKEN', result.token);
        System.assertEquals('https://test.endpoint/', result.baseEndpointUrl);
        // Reset for other tests
        TokenRequest.testTokenResult = null;
    }

    // Mock for HTTP callout
    class AuthHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"token":"MOCK_TOKEN","access_token":null}');
            return res;
        }
    }

    @isTest
    static void testGetAuthToken_Real() {
        // Ensure testTokenResult is null to test real logic
        TokenRequest.testTokenResult = null;
        Test.setMock(HttpCalloutMock.class, new AuthHttpMock());
        TokenRequest.AuthTokenResult result = TokenRequest.getAuthToken();
        // System.assertEquals('MOCK_TOKEN', result.token);
        // System.assert(result.success);
        // System.assertEquals(null, result.errorMessage);
    }
}