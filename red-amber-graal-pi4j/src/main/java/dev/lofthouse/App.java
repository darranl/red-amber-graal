package dev.lofthouse;

import com.pi4j.util.Console;

/**
 * Entry point for the traffic light controller using Pi4J.
 */
public class App {

    public static void main(String[] args) {
        int cycles = 0; // 0 = run indefinitely
        for (String arg : args) {
            if (arg.startsWith("--cycles=")) {
                cycles = Integer.parseInt(arg.substring("--cycles=".length()));
            }
        }

        final var console = new Console();
        console.title("<-- Red Amber Graal Pi4J -->", "UK Traffic Light Controller");
        console.println("Using Pi4J v4 with libgpiod on BCM pins 5 (RED), 6 (AMBER), 13 (GREEN)");
        if (cycles > 0) {
            console.println("Running " + cycles + " cycle(s) then exiting");
        } else {
            console.println("Press Ctrl+C to stop");
        }

        Thread mainThread = Thread.currentThread();
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            console.println("\nShutting down...");
            mainThread.interrupt();
        }));

        try (TrafficLightController controller = new TrafficLightController()) {
            controller.run(cycles);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        console.println("Goodbye!");
    }
}
