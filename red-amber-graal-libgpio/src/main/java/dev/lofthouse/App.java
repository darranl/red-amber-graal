package dev.lofthouse;

/**
 * Entry point for the traffic light controller using the Foreign Function & Memory API.
 */
public class App {

    public static void main(String[] args) {
        Thread mainThread = Thread.currentThread();
        Runtime.getRuntime().addShutdownHook(new Thread(mainThread::interrupt));

        try (TrafficLightController controller = new TrafficLightController()) {
            controller.run();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
