package dev.lofthouse;

import dev.lofthouse.redambergraal.ffm.gpiod_h;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;

class TrafficLightController implements AutoCloseable {

    private static final String CHIP_NAME = "gpiochip0";
    private static final String CONSUMER  = "red-amber-graal-libgpio";

    private static final int PIN_RED   = 5;
    private static final int PIN_AMBER = 6;
    private static final int PIN_GREEN = 13;

    private final Arena arena;
    private final MemorySegment chip;
    private final MemorySegment lineRed;
    private final MemorySegment lineAmber;
    private final MemorySegment lineGreen;

    private boolean closed = false;

    TrafficLightController() {
        arena = Arena.ofConfined();

        MemorySegment chipName  = arena.allocateFrom(CHIP_NAME);
        MemorySegment consumer  = arena.allocateFrom(CONSUMER);

        chip = gpiod_h.gpiod_chip_open_by_name(chipName);
        if (chip == null || chip.equals(MemorySegment.NULL)) {
            arena.close();
            throw new IllegalStateException("Failed to open GPIO chip: " + CHIP_NAME);
        }

        lineRed   = requestOutputLine(chip, PIN_RED,   consumer);
        lineAmber = requestOutputLine(chip, PIN_AMBER, consumer);
        lineGreen = requestOutputLine(chip, PIN_GREEN, consumer);
    }

    private static MemorySegment requestOutputLine(MemorySegment chip, int pin, MemorySegment consumer) {
        MemorySegment line = gpiod_h.gpiod_chip_get_line(chip, pin);
        if (line == null || line.equals(MemorySegment.NULL)) {
            throw new IllegalStateException("Failed to get GPIO line for pin " + pin);
        }
        int ret = gpiod_h.gpiod_line_request_output(line, consumer, 0);
        if (ret != 0) {
            throw new IllegalStateException("Failed to request output on pin " + pin + " (ret=" + ret + ")");
        }
        return line;
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
        setLine(lineRed,   phase.red());
        setLine(lineAmber, phase.amber());
        setLine(lineGreen, phase.green());
    }

    private static void setLine(MemorySegment line, boolean on) {
        int ret = gpiod_h.gpiod_line_set_value(line, on ? 1 : 0);
        if (ret != 0) {
            throw new IllegalStateException("gpiod_line_set_value failed (ret=" + ret + ")");
        }
    }

    @Override
    public void close() {
        if (closed) return;
        closed = true;
        gpiod_h.gpiod_line_release(lineRed);
        gpiod_h.gpiod_line_release(lineAmber);
        gpiod_h.gpiod_line_release(lineGreen);
        gpiod_h.gpiod_chip_close(chip);
        arena.close();
    }
}
