// CoverNoteRequestSenderTest this the test class for coverage this class.
public class TokenRequest {
  @TestVisible
  public static AuthTokenResult testTokenResult = null;
  // Authentication wrapper class
  public class AuthRequest {
    public String username;
    public String Password;
  }

  // Authentication response wrapper class
  public class AuthResponse {
    public String token;
    public String access_token;
    public String token_type;
    public Integer expires_in;
    public Boolean success;
    public String message;
  }

  // SAP API response wrapper class
  public class SAPResponse {
    public Boolean success;
    public String message;
    public String data;
  }
  public class AuthTokenResult {
    public String token;
    public String baseEndpointUrl;
    public Boolean success;
    public String errorMessage;
  }

  public static AuthTokenResult getAuthToken() {
    if (testTokenResult != null) {
      return testTokenResult;
    }
    AuthTokenResult result = new AuthTokenResult();
    try {
      // Get the credentials from meta data
      API_Credential__mdt cred = [
        SELECT Id, Endpoint_URL__c, Password__c, User_Name__c
        FROM API_Credential__mdt
        LIMIT 1
      ];
      result.baseEndpointUrl = cred.Endpoint_URL__c;
      AuthRequest authReq = new AuthRequest();
      authReq.username = cred.User_Name__c;
      authReq.Password = cred.Password__c;
      String endpoint = cred.Endpoint_URL__c + 'Login/Auth';

      String authPayload = JSON.serialize(authReq);

      HttpRequest req = new HttpRequest();
      req.setMethod('POST');
      req.setEndpoint(endpoint);
      req.setHeader('Content-Type', 'application/json');
      req.setBody(authPayload);
      req.setTimeout(60000); // 60 seconds timeout

      Http http = new Http();
      HttpResponse res = http.send(req);

      System.debug('Auth Response Status: ' + res.getStatusCode());
      System.debug('Auth Response Body: ' + res.getBody());
        
      ApiLogUtil.get().add('Auth', endpoint, 'POST', authPayload, res.getStatusCode(), res.getBody());

      if (res.getStatusCode() == 200) {
        AuthResponse authResponse = (AuthResponse) JSON.deserialize(
          res.getBody(),
          AuthResponse.class
        );

        // Check both possible token fields
        String token = null;
        if (String.isNotBlank(authResponse.token)) {
          token = authResponse.token;
        } else if (String.isNotBlank(authResponse.access_token)) {
          token = authResponse.access_token;
        }

        System.debug('Extracted Token: ' + token);
        result.token = token;
        result.success = true;
        result.errorMessage = null;
      } else {
        System.debug('Authentication failed. Status: ' + res.getStatus());
        result.success = false;
        result.errorMessage =
          'Authentication failed. Status: ' + res.getStatus();
      }
    } catch (Exception ex) {
      System.debug('Error during authentication: ' + ex.getMessage());
      result.success = false;
      result.errorMessage = ex.getMessage();
    }
    return result;
  }
}