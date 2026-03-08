package dev.lofthouse;

enum TrafficPhase {
    RED     (true,  false, false, 2000),
    RED_AMBER(true,  true,  false, 1000),
    GREEN   (false, false, true,  2000),
    AMBER   (false, true,  false,  750);

    private final boolean red;
    private final boolean amber;
    private final boolean green;
    private final int durationMs;

    TrafficPhase(boolean red, boolean amber, boolean green, int durationMs) {
        this.red = red;
        this.amber = amber;
        this.green = green;
        this.durationMs = durationMs;
    }

    boolean red()        { return red; }
    boolean amber()      { return amber; }
    boolean green()      { return green; }
    int     durationMs() { return durationMs; }
}
