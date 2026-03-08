package dev.lofthouse;

import com.pi4j.Pi4J;
import com.pi4j.context.Context;
import com.pi4j.io.gpio.digital.DigitalOutput;
import com.pi4j.io.gpio.digital.DigitalState;

class TrafficLightController implements AutoCloseable {

    private static final int PIN_RED   = 5;
    private static final int PIN_AMBER = 6;
    private static final int PIN_GREEN = 13;

    private final Context pi4j;
    private final DigitalOutput redLed;
    private final DigitalOutput amberLed;
    private final DigitalOutput greenLed;

    private boolean closed = false;

    TrafficLightController() {
        pi4j = Pi4J.newAutoContext();

        redLed = pi4j.digitalOutput().create(PIN_RED);
        amberLed = pi4j.digitalOutput().create(PIN_AMBER);
        greenLed = pi4j.digitalOutput().create(PIN_GREEN);
    }

    void run() throws InterruptedException {
        while (!Thread.currentThread().isInterrupted()) {
            for (TrafficPhase phase : TrafficPhase.values()) {
                applyPhase(phase);
                Thread.sleep(phase.durationMs());
            }
        }
    }

    private void applyPhase(TrafficPhase phase) {
        setState(redLed, phase.red());
        setState(amberLed, phase.amber());
        setState(greenLed, phase.green());
    }

    private static void setState(DigitalOutput output, boolean on) {
        if (on) {
            output.high();
        } else {
            output.low();
        }
    }

    @Override
    public void close() {
        if (closed) return;
        closed = true;
        pi4j.shutdown();
    }
}
