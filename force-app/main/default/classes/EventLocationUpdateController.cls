public with sharing class EventLocationUpdateController {

    @AuraEnabled(cacheable=true)
    public static String getEventDescription(Id eventId) {
        try {
            Event e = [SELECT Id, Description FROM Event WHERE Id = :eventId LIMIT 1];
            return e.Description != null ? e.Description : 'No description available';
        } catch (Exception ex) {
            return 'Error loading description';
        }
    }

    // NEW: Fetch current remarks for prefill in modal
    @AuraEnabled(cacheable=true)
    public static String getEventRemarks(Id eventId) {
        try {
            Event e = [SELECT Id, Remarks__c FROM Event WHERE Id = :eventId LIMIT 1];
            return e.Remarks__c == null ? '' : e.Remarks__c;
        } catch (Exception ex) {
            // Return empty so UI still opens gracefully
            return '';
        }
    }

    // Added cacheable=true earlier for wire/imperative usage
    @AuraEnabled(cacheable=true)
    public static Map<String, Boolean> getEventStatusSimple(Id eventId) {
        Map<String, Boolean> result = new Map<String, Boolean>();
        try {
            Event e = [
                SELECT Id,
                       Check_In_Location__Latitude__s,
                       Check_In_Location__Longitude__s,
                       Check_Out_Location__Latitude__s,
                       Check_Out_Location__Longitude__s,
                       Status__c
                FROM Event
                WHERE Id = :eventId
                LIMIT 1
            ];

            Boolean hasCheckIn = (e.Check_In_Location__Latitude__s != null &&
                                  e.Check_In_Location__Longitude__s != null);

            Boolean hasCheckOut = (e.Check_Out_Location__Latitude__s != null &&
                                   e.Check_Out_Location__Longitude__s != null);

            Boolean isNotCompleted = (e.Status__c == 'Not Completed');

            result.put('hasCheckIn', hasCheckIn);
            result.put('hasCheckOut', hasCheckOut);
            result.put('isNotCompleted', isNotCompleted);

            System.debug('Event Status Check - CheckIn: ' + hasCheckIn + ', CheckOut: ' + hasCheckOut + ', NotCompleted: ' + isNotCompleted);
        } catch (Exception ex) {
            System.debug('Error in getEventStatusSimple: ' + ex.getMessage());
            result.put('hasCheckIn', false);
            result.put('hasCheckOut', false);
            result.put('isNotCompleted', false);
        }
        return result;
    }

    @AuraEnabled
    public static String updateEventLocation(Id eventId, Double lat, Double lon, Boolean isCheckIn) {
        try {
            Event e = [
                SELECT Id,
                       Check_In_Location__Latitude__s, Check_In_Location__Longitude__s,
                       Check_Out_Location__Latitude__s, Check_Out_Location__Longitude__s
                FROM Event
                WHERE Id = :eventId
                LIMIT 1
            ];

            if (isCheckIn) {
                e.Check_In_Location__Latitude__s = lat;
                e.Check_In_Location__Longitude__s = lon;
            } else {
                e.Check_Out_Location__Latitude__s = lat;
                e.Check_Out_Location__Longitude__s = lon;
            }

            update e;
            return 'Event location updated successfully!';
        } catch (Exception ex) {
            throw new AuraHandledException('Error updating event location: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static String updateEventRemarks(Id eventId, String remarks) {
        try {
            Event e = [SELECT Id, Remarks__c FROM Event WHERE Id = :eventId LIMIT 1];
            e.Remarks__c = remarks;
            update e;
            return 'Event remarks updated successfully!';
        } catch (Exception ex) {
            throw new AuraHandledException('Error updating event remarks: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static String markEventNotCompleted(Id eventId, String reason, String descriptionText) {
        try {
            Event e = new Event(
                Id = eventId,
                Incomplete_Visit_Reason__c = reason,
                Description__c = descriptionText,
                Status__c = 'Not Completed'
            );
            update e;
            return 'Marked as Not Completed';
        } catch (Exception ex) {
            throw new AuraHandledException('Error marking as Not Completed: ' + ex.getMessage());
        }
    }

    public class EventStatusWrapper {
        @AuraEnabled public Boolean hasCheckIn { get; set; }
        @AuraEnabled public Boolean hasCheckOut { get; set; }
        @AuraEnabled public Boolean isNotCompleted { get; set; }

        public EventStatusWrapper() {
            this.hasCheckIn = false;
            this.hasCheckOut = false;
            this.isNotCompleted = false;
        }
    }
}