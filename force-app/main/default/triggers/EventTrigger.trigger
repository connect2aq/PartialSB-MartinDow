// EventTrigger - Save this in separate trigger file
trigger EventTrigger on Event (before insert) {
    VisitPlanningHandler.applyStatusFromParent(Trigger.new);
}