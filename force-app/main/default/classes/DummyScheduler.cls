public class DummyScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        // This code will be executed when the scheduled job runs.
        // Add your logic here.
        System.debug('Dummy Scheduler Job is running!');
        // Example: Log a debug message or perform some action.
    }
}