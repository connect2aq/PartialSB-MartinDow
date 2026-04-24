@isTest
public class LeadControllerTest {
  @isTest
  static void testGetLeads() {
    Lead l1 = new Lead(
      LastName = 'Smith',
      Company = 'Acme',
      Status = 'Open - Not Contacted'
    );
    Lead l2 = new Lead(
      LastName = 'Jones',
      Company = 'Beta',
      Status = 'Open - Not Contacted'
    );
    insert new List<Lead>{ l1, l2 };
    Test.startTest();
    List<Lead> leads = LeadController.getLeads('Smith');
    Test.stopTest();
    System.assert(leads.size() > 0, 'Should return at least one lead');
    // LastName is not queried by controller, so re-query for assertion
    List<Id> leadIds = new List<Id>();
    for (Lead ld : leads) {
      leadIds.add(ld.Id);
    }
    Map<Id, Lead> idToLead = new Map<Id, Lead>(
      [SELECT Id, LastName FROM Lead WHERE Id IN :leadIds]
    );
    System.assertEquals('Smith', idToLead.get(leads[0].Id).LastName);
  }

  @isTest
  static void testGetLeadById() {
    Lead l = new Lead(
      LastName = 'Brown',
      Company = 'Gamma',
      Status = 'Open - Not Contacted'
    );
    insert l;
    Test.startTest();
    Lead result = LeadController.getLeadById(l.Id);
    Test.stopTest();
    System.assertEquals(l.Id, result.Id);
    // LastName is not queried by controller, so re-query for assertion
    Lead queried = [SELECT LastName FROM Lead WHERE Id = :result.Id];
    System.assertEquals('Brown', queried.LastName);
  }

  @isTest
  static void testCreateLead() {
    Test.startTest();
    Lead l = LeadController.createLead(
      'Taylor',
      'Delta',
      'Open - Not Contacted'
    );
    Test.stopTest();
    System.assertNotEquals(null, l.Id);
    System.assertEquals('Taylor', l.LastName);
    System.assertEquals('Delta', l.Company);
    System.assertEquals('Open - Not Contacted', l.Status);
  }
}