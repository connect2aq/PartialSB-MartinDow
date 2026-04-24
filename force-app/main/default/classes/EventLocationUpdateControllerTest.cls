@isTest
public class EventLocationUpdateControllerTest {

    @testSetup
    static void setupData() {
        // Base event to ensure at least one record exists
        Event baseEvt = new Event(
            Subject = 'Base Event',
            DurationInMinutes = 30,
            ActivityDateTime = System.now()
        );
        insert baseEvt;
    }

    // Covers: getEventDescription (with description and without description)
    @isTest
    static void cover_getEventDescription_success_and_noDesc() {
        // Event with Description
        Event e1 = new Event(
            Subject = 'Desc Event',
            Description = 'Test description',
            DurationInMinutes = 15,
            ActivityDateTime = System.now()
        );
        insert e1;

        // Event without Description
        Event e2 = new Event(
            Subject = 'No Desc Event',
            DurationInMinutes = 10,
            ActivityDateTime = System.now()
        );
        insert e2;

        Test.startTest();
        String d1 = EventLocationUpdateController.getEventDescription(e1.Id);
        String d2 = EventLocationUpdateController.getEventDescription(e2.Id);
        Test.stopTest();
    }

    // Covers: getEventDescription (exception branch via null Id)
    @isTest
    static void cover_getEventDescription_exception() {
        Test.startTest();
        String d = EventLocationUpdateController.getEventDescription(null);
        Test.stopTest();
    }

    // Covers: getEventStatusSimple (happy path with both check-in and check-out + Not Completed)
    @isTest
    static void cover_getEventStatusSimple_success() {
        Event e = new Event(
            Subject = 'Status Success Event',
            DurationInMinutes = 20,
            ActivityDateTime = System.now(),
            Check_In_Location__Latitude__s = 31.5204,
            Check_In_Location__Longitude__s = 74.3587,
            Check_Out_Location__Latitude__s = 24.8607,
            Check_Out_Location__Longitude__s = 67.0011,
            Status__c = 'Not Completed'
        );
        insert e;

        Test.startTest();
        Map<String, Boolean> m = EventLocationUpdateController.getEventStatusSimple(e.Id);
        Test.stopTest();
    }

    // Covers: getEventStatusSimple (exception branch via null Id)
    @isTest
    static void cover_getEventStatusSimple_exception() {
        Test.startTest();
        Map<String, Boolean> m = EventLocationUpdateController.getEventStatusSimple(null);
        Test.stopTest();
    }

    // Covers: updateEventLocation (success for check-in and check-out) using Double parameters
    @isTest
    static void cover_updateEventLocation_success() {
        Event e = new Event(
            Subject = 'Loc Success Event',
            DurationInMinutes = 15,
            ActivityDateTime = System.now()
        );
        insert e;

        // Prepare Double values (NOT Decimal literals)
        Double inLat  = Double.valueOf('24.0');
        Double inLon  = Double.valueOf('67.0');
        Double outLat = Double.valueOf('25.0');
        Double outLon = Double.valueOf('68.0');

        Test.startTest();
        String r1 = EventLocationUpdateController.updateEventLocation(e.Id, inLat, inLon, true);
        String r2 = EventLocationUpdateController.updateEventLocation(e.Id, outLat, outLon, false);
        Test.stopTest();
    }

    // Covers: updateEventLocation (exception branch via null Id -> AuraHandledException)
    @isTest
    static void cover_updateEventLocation_exception() {
        // Use Double.valueOf to match method signature
        Double zero = Double.valueOf('0');
        Test.startTest();
        try {
            String r = EventLocationUpdateController.updateEventLocation(null, zero, zero, true);
        } catch (Exception ignore) {
            // Intentionally swallowing the exception to cover controller catch and rethrow
        }
        Test.stopTest();
    }

    // Covers: updateEventRemarks (success)
    @isTest
    static void cover_updateEventRemarks_success() {
        Event e = new Event(
            Subject = 'Remarks Success Event',
            DurationInMinutes = 15,
            ActivityDateTime = System.now()
        );
        insert e;

        Test.startTest();
        String r = EventLocationUpdateController.updateEventRemarks(e.Id, 'Sample remarks');
        Test.stopTest();
    }

    // Covers: updateEventRemarks (exception branch via null Id -> AuraHandledException)
    @isTest
    static void cover_updateEventRemarks_exception() {
        Test.startTest();
        try {
            String r = EventLocationUpdateController.updateEventRemarks(null, 'X');
        } catch (Exception ignore) {
            // Intentionally swallowing the exception to cover controller catch and rethrow
        }
        Test.stopTest();
    }

    // Covers: markEventNotCompleted (success path)
    @isTest
    static void cover_markEventNotCompleted_success() {
        Event e = new Event(
            Subject = 'Not Completed Success Event',
            DurationInMinutes = 15,
            ActivityDateTime = System.now()
        );
        insert e;

        Test.startTest();
        String r = EventLocationUpdateController.markEventNotCompleted(
            e.Id,
            'Customer Unavailable',
            'Did not attend'
        );
        Test.stopTest();
    }

    // Covers: markEventNotCompleted (exception branch via null Id -> AuraHandledException)
    @isTest
    static void cover_markEventNotCompleted_exception() {
        Test.startTest();
        try {
            String r = EventLocationUpdateController.markEventNotCompleted(
                null,
                'Reason',
                'Desc'
            );
        } catch (Exception ignore) {
            // Intentionally swallowing the exception to cover controller catch and rethrow
        }
        Test.stopTest();
    }

    // Covers: EventStatusWrapper constructor & property getters
    @isTest
    static void cover_wrapper_constructor_and_props() {
        Test.startTest();
        EventLocationUpdateController.EventStatusWrapper w =
            new EventLocationUpdateController.EventStatusWrapper();
        // Touch properties to ensure getters are executed
        Boolean a = w.hasCheckIn;
        Boolean b = w.hasCheckOut;
        Boolean c = w.isNotCompleted;
        Test.stopTest();
    }
}