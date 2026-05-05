public without sharing class ApiLogUtil {
    
    private static ApiLogUtil inst;
    private List<API_Log__c> buffer;
    
    // Keep some headroom under 32768 to avoid edge errors
    private static final Integer MAX_LONG_TEXT = 32000;
    private static final Integer MAX_TEXT_255 = 255;
    
    private ApiLogUtil() {
        this.buffer = new List<API_Log__c>();
    }
    
    public static ApiLogUtil get() {
        if (inst == null) {
            inst = new ApiLogUtil();
        }
        return inst;
    }

   public void add(
    String apiName,
    String apiUrl,
    String requestMethod,   // "GET" | "POST"
    String requestBody,
    Integer responseCode,
    String responseMessage
) {
    // English comment: Read logging mode from Custom Metadata (Decision).
    String mode;
    try {
        API_Log_Setup__mdt cfg = [
            SELECT Status__c
            FROM API_Log_Setup__mdt
            WHERE DeveloperName = 'Decision'
            LIMIT 1
        ];
        mode = String.valueOf(cfg.Status__c);
    } catch (Exception e) {
        mode = null; // English comment: If missing/exception, treat as disabled (no logs)
    }

    // English comment: If null/blank -> no logging.
    if (String.isBlank(mode)) {
        return;
    }

    // English comment: BASIC -> log minimal fields only.
    if (mode == 'BASIC') {
        API_Log__c recBasic = new API_Log__c();
        recBasic.API_Name__c     = trimTo(apiName, MAX_TEXT_255);
        recBasic.API_URL__c      = trimTo(apiUrl, MAX_TEXT_255);
        recBasic.Response_Code__c = responseCode;
        this.buffer.add(recBasic);
        return;
    }

    // English comment: DEBUG (or any other non-blank value) -> full detailed log (existing behavior).
    API_Log__c rec = new API_Log__c();
    rec.API_Name__c        = trimTo(apiName, MAX_TEXT_255);
    rec.API_URL__c         = trimTo(apiUrl, MAX_TEXT_255);
    rec.Request_Method__c  = safePick(requestMethod);
    rec.Request_Body__c    = concise(requestBody);
    rec.Response_Code__c   = responseCode;
    rec.Response_Message__c= concise(responseMessage);

    this.buffer.add(rec);
}
    
    // Clear the in-memory buffer (useful after flush)
    public void clear() {
        this.buffer.clear();
    }

    public Integer size() {
        return this.buffer.size();
    }
    
    public void flushSync() {
        if(this.buffer.size() == 0) return;
        insert this.buffer;
        this.buffer.clear();
    }

    // -------- Helpers (keep values concise to prevent insert failure) --------
    // Keep only meaningful content and truncate to MAX_LONG_TEXT
    private static String concise(String s) {
        if (String.isBlank(s)) return null;
        // Remove excessive whitespace to make it compact
        // (keeps single spaces; preserves payload meaning)
        String compacted = replaceAllInChunks(s, '\\s+', ' ', 20000);
        compacted = replaceAllInChunks(compacted, '\\s+', ' ', 20000);
        if (compacted.length() > MAX_LONG_TEXT) {
            return compacted.substring(0, MAX_LONG_TEXT);
        }
        return compacted;
    }
    
    
    private static String replaceAllInChunks(String input, String findToken, String replacement, Integer chunkSize) {
        // Safety checks
        if (String.isBlank(input)) return input;
        if (String.isBlank(findToken) || findToken == replacement) return input;
        if (chunkSize == null || chunkSize <= 0) chunkSize = 5000;
    
        if(input.length() <= chunkSize) return input.replaceAll(findToken, replacement);
    
        List<String> out = new List<String>();
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(input.length(), i + chunkSize);
            String chunk = input.substring(i, endIndex);
            // String.replace in Apex is literal (not regex), safe for large chunks
            chunk = chunk.replaceAll(findToken, replacement);
            out.add(chunk);
        }
        
        return String.join(out, '');
    }
    // Trim any 255-char text fields safely
    private static String trimTo(String s, Integer maxLen) {
        if (String.isBlank(s)) return null;
        return (s.length() > maxLen) ? s.substring(0, maxLen) : s;
    }

    // Enforce only expected picklist values to avoid bad data
    private static String safePick(String method) {
        if (String.isBlank(method)) return null;
        String m = method.trim().toUpperCase();
        if (m == 'GET' || m == 'POST') return m;
        // If something else slips through, keep it null to avoid picklist failures
        return null;
    }
}