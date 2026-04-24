public with sharing class MDPlanApprovalService {

    public class MDPlanApprovalResult {
        @AuraEnabled
        public Boolean success;

        @AuraEnabled
        public String message;
    }

    @AuraEnabled
    public static MDPlanApprovalResult processApproval(Id recordId, String action, String comment) {
        MDPlanApprovalResult result = new MDPlanApprovalResult();
        result.success = false;

        if (recordId == null) {
            result.message = 'Record Id is required.';
            return result;
        }

        if (String.isBlank(action)) {
            result.message = 'Action (Approve / Reject) is required.';
            return result;
        }

        String normalizedAction = action.trim().toUpperCase();
        if (normalizedAction != 'APPROVE' && normalizedAction != 'REJECT') {
            result.message = 'Invalid action. Use Approve or Reject.';
            return result;
        }

        try {
            // Find the current pending approval work item for this record
            List<ProcessInstanceWorkitem> workItems = [
                SELECT Id,
                       ActorId,
                       ProcessInstance.TargetObjectId,
                       ProcessInstance.Status
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                  AND ProcessInstance.Status = 'Pending'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (workItems.isEmpty()) {
                result.message = 'No pending approval found for this record for the current user.';
                return result;
            }

            ProcessInstanceWorkitem workItem = workItems[0];

            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setWorkitemId(workItem.Id);

            if (!String.isBlank(comment)) {
                req.setComments(comment);
            }

            if (normalizedAction == 'APPROVE') {
                req.setAction('Approve');
            } else {
                req.setAction('Reject');
            }

            // Call the Approval engine
            Approval.ProcessResult processResult = Approval.process(req);

            // If no exception was thrown, treat this as success
            result.success = true;
            if (normalizedAction == 'APPROVE') {
                result.message = 'Plan has been approved successfully.';
            } else {
                result.message = 'Plan has been rejected successfully.';
            }

        } catch (Exception ex) {
            // Any exception from Approval.process will be handled here
            result.message = ex.getMessage();
        }

        return result;
    }
}