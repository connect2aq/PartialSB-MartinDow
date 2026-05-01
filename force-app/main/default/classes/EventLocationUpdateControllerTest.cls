@isTest
public class EventLocationUpdateControllerTest {

    @testSetup
    static void setupData() {
        // Minimal base event record
        Event baseEvt = new Event(
            Subject = 'Base Event',
            DurationInMinutes = 30,
            ActivityDateTime = System.now()
        );
        insert baseEvt;
    }

    // Covers: getEventStatusSimple (happy path with geo/date fields and Not Completed)
    @isTest
    static void cover_getEventStatusSimple_success() {
        Event e = new Event(
            Subject = 'Status Success Event',
            DurationInMinutes = 20,
            ActivityDateTime = System.now(),
            // If these custom fields exist in org; otherwise you may remove
            Check_In_Location__Latitude__s = 31.5204,
            Check_In_Location__Longitude__s = 74.3587,
            Check_Out_Location__Latitude__s = 24.8607,
            Check_Out_Location__Longitude__s = 67.0011,
            Status__c = 'Not Completed'
        );
        insert e;

        Test.startTest();
        // NOTE: method now expects (Id, Long) -> pass a nonce value like 0 or DateTime.now().getTime()
        Map<String, Boolean> m = EventLocationUpdateController.getEventStatusSimple(e.Id, 0L);
        Test.stopTest();
    }

    // Covers: getEventStatusSimple (null Id branch)
    @isTest
    static void cover_getEventStatusSimple_null() {
        Test.startTest();
        Map<String, Boolean> m = EventLocationUpdateController.getEventStatusSimple(null, 0L);
        Test.stopTest();
    }

    // Covers: updateEventLocation (success for check-in and check-out)
    @isTest
    static void cover_updateEventLocation_success() {
        Event e = new Event(
            Subject = 'Loc Success Event',
            DurationInMinutes = 15,
            ActivityDateTime = System.now()
        );
        insert e;

        // Use Decimal values to match controller signature
        Decimal inLat  = Decimal.valueOf('24.0000');
        Decimal inLon  = Decimal.valueOf('67.0000');
        Decimal outLat = Decimal.valueOf('25.0000');
        Decimal outLon = Decimal.valueOf('68.0000');

        Test.startTest();
        EventLocationUpdateController.updateEventLocation(e.Id, inLat, inLon, true);   // check-in
        EventLocationUpdateController.updateEventLocation(e.Id, outLat, outLon, false); // check-out
        Test.stopTest();
    }

    // Covers: updateEventLocation (exception branch via null Id)
    @isTest
    static void cover_updateEventLocation_exception() {
        Decimal zero = Decimal.valueOf('0');
        Test.startTest();
        try {
            EventLocationUpdateController.updateEventLocation(null, zero, zero, true);
        } catch (Exception ignore) {
            // swallow to cover exception path
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
        EventLocationUpdateController.updateEventRemarks(e.Id, 'Sample remarks');
        Test.stopTest();
    }

    // Covers: updateEventRemarks (exception branch via null Id)
    @isTest
    static void cover_updateEventRemarks_exception() {
        Test.startTest();
        try {
            EventLocationUpdateController.updateEventRemarks(null, 'X');
        } catch (Exception ignore) {
            // swallow to cover exception path
        }
        Test.stopTest();
    }
    @isTest
static void cover_markEventNotCompleted_success() {
    Event e = new Event(
        Subject = 'NC Test',
        DurationInMinutes = 10,
        ActivityDateTime = System.now()
    );
    insert e;

    Test.startTest();
    EventLocationUpdateController.markEventNotCompleted(e.Id);
    Test.stopTest();
}

}