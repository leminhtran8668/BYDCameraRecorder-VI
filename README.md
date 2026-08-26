# BYD Camera Recorder (Tiếng Việt)

Ứng dụng hộp đen Android sử dụng camera AVM tích hợp trên xe BYD.

## Tính năng

- **Ghi hình 4 kênh 360°** — Mã hóa H.264 đồng thời camera trước/sau/trái/phải
- **Lớp phủ GPS/tốc độ** — Ghép tốc độ, tọa độ, thời gian lên video; lưu quỹ đạo GPX
- **Chế độ giám sát đỗ xe** — Phát hiện va chạm bằng cảm biến gia tốc, tự ghi và khóa đoạn
- **Truy cập từ điện thoại** — Kết nối Wi-Fi xe, xem và tải video qua trình duyệt hoặc app Flutter
- **Quản lý đoạn ghi tự động** — Xóa đoạn cũ khi đầy dung lượng (bảo vệ đoạn đã khóa)
- **Ghi vào thẻ SD** — Chọn ổ lưu trữ (bộ nhớ trong hoặc thẻ SD)

## Xe tương thích

| Mẫu xe | Trạng thái |
|--------|------------|
| BYD Atto 3 | Đã kiểm tra |
| BYD Seal | Dự kiến tương thích |
| BYD Dolphin | Dự kiến tương thích |
| BYD Sealion 7 | Dự kiến tương thích |

Hoạt động trên xe dùng API `AVMCamera` của BYD.

## Yêu cầu

- Android SDK (Build-tools, API 23+)
- JDK 8+
- ADB

## Build

```bash
bash build.sh
# → build/byd-dashcam-debug.apk
```

### Build kèm Phone UI

```bash
npm --prefix phone-ui install
npm --prefix phone-ui run build
bash build.sh
```

### GitHub Actions

Push tag `v*` hoặc chạy workflow thủ công để build APK xe + APK điện thoại và tạo Release.

## Cài đặt

```bash
adb install -r build/byd-dashcam-debug.apk
adb shell pm grant com.ggpark.byddashcam android.permission.CAMERA
adb shell pm grant com.ggpark.byddashcam android.permission.ACCESS_FINE_LOCATION
adb shell dumpsys deviceidle whitelist +com.ggpark.byddashcam
```

## Cấu trúc dự án

```
src/          Mã Java app xe
phone-ui/     Web UI remote (Vite + Svelte) — tiếng Việt
mobile/       App điện thoại Flutter — tiếng Việt
res/          Resource Android (values-vi tiếng Việt mặc định)
build.sh      Script build
```

## Ngôn ngữ

- Mặc định: **Tiếng Việt**
- Có thể chuyển sang English trong Cài đặt trên xe

## Giấy phép

MIT
