package com.ggpark.byddashcam;

/**
 * Bộ phát hiện chuyển động dựa trên chênh lệch pixel giữa các khung hình liên tiếp.
 *
 * Chỉ dùng kênh Y (độ sáng) trong định dạng NV21 (YUV420sp).
 * Giảm tải CPU bằng cách down-sample theo khối 16×16.
 *
 * sensitivity 1~5:
 *   1 = nhạy nhất (phát hiện cả chuyển động nhỏ)
 *   5 = kém nhạy nhất (chỉ phát hiện chuyển động lớn)
 */
public final class CameraMotionDetector {

    // Kích thước khối down-sample (pixel)
    private static final int BLOCK_SIZE = 16;
    // Ngưỡng chênh lệch pixel kênh Y (0~255)
    private static final int PIXEL_DIFF_THRESHOLD = 20;

    // Ngưỡng tỷ lệ khối chuyển động theo sensitivity
    // sensitivity 1: 0.5%, 5: 6.0%
    private static final float[] MOTION_RATIO_BY_SENSITIVITY = {
        0.005f,  // 1 (very sensitive)
        0.015f,  // 2
        0.030f,  // 3 (default)
        0.045f,  // 4
        0.060f,  // 5 (least sensitive)
    };

    private byte[] previousSampled;
    private int sampledWidth;
    private int sampledHeight;
    private float motionRatioThreshold = MOTION_RATIO_BY_SENSITIVITY[2];

    public void setSensitivity(int sensitivity) {
        int clamped = Math.max(1, Math.min(5, sensitivity));
        motionRatioThreshold = MOTION_RATIO_BY_SENSITIVITY[clamped - 1];
    }

    /**
     * Gửi khung hình để phát hiện chuyển động.
     *
     * @param data   Dữ liệu khung định dạng NV21
     * @param width  Chiều ngang khung (pixel)
     * @param height Chiều dọc khung (pixel)
     * @return true nếu phát hiện chuyển động; false nếu khung đầu hoặc dưới ngưỡng
     */
    public boolean detect(byte[] data, int width, int height) {
        if (data == null || data.length < width * height) {
            return false;
        }
        // Chỉ down-sample kênh Y (width*height byte đầu của NV21)
        int sw = (width + BLOCK_SIZE - 1) / BLOCK_SIZE;
        int sh = (height + BLOCK_SIZE - 1) / BLOCK_SIZE;
        byte[] sampled = new byte[sw * sh];

        for (int by = 0; by < sh; by++) {
            for (int bx = 0; bx < sw; bx++) {
                int sum = 0;
                int count = 0;
                int yStart = by * BLOCK_SIZE;
                int xStart = bx * BLOCK_SIZE;
                int yEnd = Math.min(yStart + BLOCK_SIZE, height);
                int xEnd = Math.min(xStart + BLOCK_SIZE, width);
                for (int py = yStart; py < yEnd; py++) {
                    int rowOffset = py * width;
                    for (int px = xStart; px < xEnd; px++) {
                        sum += data[rowOffset + px] & 0xFF;
                        count++;
                    }
                }
                sampled[by * sw + bx] = (byte) (sum / count);
            }
        }

        if (previousSampled == null
                || sampledWidth != sw
                || sampledHeight != sh) {
            previousSampled = sampled;
            sampledWidth = sw;
            sampledHeight = sh;
            return false;
        }

        int changedBlocks = 0;
        for (int i = 0; i < sampled.length; i++) {
            int diff = Math.abs((sampled[i] & 0xFF) - (previousSampled[i] & 0xFF));
            if (diff > PIXEL_DIFF_THRESHOLD) {
                changedBlocks++;
            }
        }
        previousSampled = sampled;

        return changedBlocks > sampled.length * motionRatioThreshold;
    }

    /** Khởi tạo lại buffer khung trước (gọi khi đổi chế độ). */
    public void reset() {
        previousSampled = null;
    }
}
