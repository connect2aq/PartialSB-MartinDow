// comments in English only
public with sharing class EventLocationUpdateController {

    // NOTE: Adjust field API names if different in your org.
    // Assumed fields on Event:
    //  - Status__c (Picklist: includes 'Not Completed')
    //  - Check_In_Date_Time__c (DateTime)
    //  - Check_Out_Date_Time__c (DateTime)
    //  - Check_In_Location__c (Geolocation)  -> use ...__Latitude__s / ...__Longitude__s
    //  - Check_Out_Location__c (Geolocation) -> use ...__Latitude__s / ...__Longitude__s
    //  - Remarks__c (Long Text Area), optional

    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getEventStatusSimple(Id eventId, Long nonce) {
        // 'nonce' is intentionally unused; it only busts the platform's cache.
        if (eventId == null) {
            return new Map<String, Boolean>{
                'hasCheckIn' => false,
                'hasCheckOut' => false,
                'isNotCompleted' => false
            };
        }

        Event rec = [
            SELECT  Status__c,
                    Check_In_Date_Time__c,
                    Check_Out_Date_Time__c,
                    Check_In_Location__Latitude__s,
                    Check_In_Location__Longitude__s,
                    Check_Out_Location__Latitude__s,
                    Check_Out_Location__Longitude__s
            FROM Event
            WHERE Id = :eventId
            LIMIT 1
        ];

        Boolean hasCheckIn = (rec.Check_In_Date_Time__c != null)
                             || (rec.Check_In_Location__Latitude__s != null && rec.Check_In_Location__Longitude__s != null);
        Boolean hasCheckOut = (rec.Check_Out_Date_Time__c != null)
                              || (rec.Check_Out_Location__Latitude__s != null && rec.Check_Out_Location__Longitude__s != null);
        Boolean isNotCompleted = (rec.Status__c == 'Not Completed');

        return new Map<String, Boolean>{
            'hasCheckIn' => hasCheckIn,
            'hasCheckOut' => hasCheckOut,
            'isNotCompleted' => isNotCompleted
        };
    }

    @AuraEnabled
    public static void updateEventLocation(Id eventId, Decimal lat, Decimal lon, Boolean isCheckIn) {
        if (eventId == null || lat == null || lon == null || isCheckIn == null) {
            throw new AuraHandledException('Invalid parameters.');
        }

        Event upd = new Event();
        upd.Id = eventId;

        if (isCheckIn) {
            // Set geolocation components
            upd.put('Check_In_Location__Latitude__s', lat);
            upd.put('Check_In_Location__Longitude__s', lon);
            // Stamp Date/Time
            upd.put('Check_In_Date_Time__c', System.now());
        } else {
            upd.put('Check_Out_Location__Latitude__s', lat);
            upd.put('Check_Out_Location__Longitude__s', lon);
            upd.put('Check_Out_Date_Time__c', System.now());
        }

        update upd;
    }

    @AuraEnabled
    public static void updateEventRemarks(Id eventId, String remarks) {
        if (eventId == null) {
            throw new AuraHandledException('Invalid parameters.');
        }
        Event upd = new Event(
            Id = eventId
        );
        // Adjust API name if your Remarks field is different
        upd.put('Remarks__c', remarks);
        update upd;
    }

    @AuraEnabled(cacheable=true)
    public static String getEventRemarks(Id eventId) {
        if (eventId == null) return null;
        Event rec = [
            SELECT Remarks__c
            FROM Event
            WHERE Id = :eventId
            LIMIT 1
        ];
        return (String)rec.get('Remarks__c');
    }
    // comments in English only
@AuraEnabled
public static void markEventNotCompleted(Id eventId) {
    if (eventId == null) {
        throw new AuraHandledException('Invalid parameters.');
    }
    // Update only the fields needed for "Not Completed" state
    Event upd = new Event(
        Id = eventId
    );
    upd.put('Status__c', 'Not Completed');
    // (Optional) clear checkout fields if your business rule needs it:
    // upd.put('Check_Out_Date_Time__c', null);
    // upd.put('Check_Out_Location__Latitude__s', null);
    // upd.put('Check_Out_Location__Longitude__s', null);

    update upd;
}
    @AuraEnabled(cacheable=true)
public static String getEventDescription(Id eventId) {
    if (eventId == null) {
        return '';
    }

    Event e = [
        SELECT Description
        FROM Event
        WHERE Id = :eventId
        LIMIT 1
    ];

    return e.Description;
}


}