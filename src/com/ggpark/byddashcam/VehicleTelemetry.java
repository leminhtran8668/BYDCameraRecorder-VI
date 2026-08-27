package com.ggpark.byddashcam;

/** Snapshot dữ liệu telemetry xe. Đối tượng bất biến. Cùng cấu trúc với GpsFix. */
public final class VehicleTelemetry {
    /** Giá trị sentinel khi không dùng telemetry hoặc máy không hỗ trợ API BYD */
    public static final VehicleTelemetry UNAVAILABLE =
            new VehicleTelemetry(0, 0, 0, 0, 0);

    /** Tốc độ (km/h, kẹp 0-255) */
    public final int speedKmh;
    /** Độ sâu bàn đạp ga (0-100%) */
    public final int acceleratorPercent;
    /** Độ sâu bàn đạp phanh (0-100%) */
    public final int brakePercent;
    /**
     * 기어/방향지시등/안전벨트 복합 플래그.
     * bit0=P, bit1=R, bit2=N, bit3=D, bit4=좌회전등, bit5=우회전등, bit6=안전벨트
     */
    public final int gearBlinkBeltFlags;
    /**
     * 조명 상태 플래그.
     * bit0=위치등, bit1=하향등, bit2=상향등, bit3=안개등
     */
    public final int lightFlags;

    public VehicleTelemetry(
            int speedKmh,
            int acceleratorPercent,
            int brakePercent,
            int gearBlinkBeltFlags,
            int lightFlags) {
        this.speedKmh = speedKmh;
        this.acceleratorPercent = acceleratorPercent;
        this.brakePercent = brakePercent;
        this.gearBlinkBeltFlags = gearBlinkBeltFlags;
        this.lightFlags = lightFlags;
    }

    public boolean isAvailable() {
        return this != UNAVAILABLE;
    }

    /** 현재 기어 문자를 반환합니다. 복수 비트 설정 시 Thứ tự ưu tiên: P > R > N > D */
    public char gearChar() {
        if ((gearBlinkBeltFlags & 0x01) != 0) return 'P';
        if ((gearBlinkBeltFlags & 0x02) != 0) return 'R';
        if ((gearBlinkBeltFlags & 0x04) != 0) return 'N';
        if ((gearBlinkBeltFlags & 0x08) != 0) return 'D';
        return '?';
    }

    public boolean isTurnLeftActive() {
        return (gearBlinkBeltFlags & (1 << 4)) != 0;
    }

    public boolean isTurnRightActive() {
        return (gearBlinkBeltFlags & (1 << 5)) != 0;
    }

    public boolean isGearKnown() {
        return (gearBlinkBeltFlags & 0x0f) != 0;
    }
}
