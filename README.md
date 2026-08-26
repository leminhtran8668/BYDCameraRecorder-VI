# BYD Camera Recorder

Ứng dụng hộp đen Android dùng camera AVM tích hợp trên xe BYD.

## Tính năng

- **Ghi 4 kênh 360°** — Đồng thời mã hóa H.264 camera trước/sau/trái/phải
- **Lớp phủ GPS/tốc độ** — Ghép tốc độ, tọa độ, thời gian lên video; lưu quỹ đạo GPX
- **Chế độ giám sát đỗ xe** — Cảm biến gia tốc phát hiện va chạm → tự ghi và khóa đoạn
- **Truy cập từ điện thoại** — Kết nối Wi-Fi xe, xem/tải video bằng trình duyệt hoặc app Flutter
- **Quản lý đoạn tự động** — Xóa đoạn cũ khi vượt dung lượng (bảo vệ bản ghi đã khóa)
- **Ghi lên thẻ nhớ SD** — Chọn ổ lưu trong Cài đặt (bộ nhớ trong hoặc thẻ SD)

## Xe tương thích

| Mẫu xe | Trạng thái |
|--------|------------|
| BYD Atto 3 | Đã kiểm chứng |
| BYD Seal | Dự kiến tương thích · chưa kiểm chứng |
| BYD Dolphin | Dự kiến tương thích · chưa kiểm chứng |
| BYD Sealion 7 | Dự kiến tương thích · chưa kiểm chứng |

Hoạt động trên xe dùng API `AVMCamera` của BYD. Thêm mẫu mới bằng cách triển khai `VehicleProfile` và gửi PR.

## Yêu cầu

- Android SDK (kèm Build-tools, API 23+)
- JDK 8 trở lên
- ADB (cài đặt và kiểm thử)

## Build

```bash
bash build.sh
# → build/byd-dashcam-debug.apk
```

### Build release

```bash
BYD_CAMERA_SIGNING_MODE=release \
BYD_CAMERA_RELEASE_SIGNING_DIR=/path/to/signing \
bash build.sh
```

### Build kèm Phone UI

Nếu sửa UI truy cập từ điện thoại, build trước:

```bash
npm --prefix phone-ui install
npm --prefix phone-ui run build
bash build.sh
```

## Cài đặt

```bash
adb install -r build/byd-dashcam-debug.apk

adb shell pm grant com.ggpark.byddashcam android.permission.CAMERA
adb shell pm grant com.ggpark.byddashcam android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.ggpark.byddashcam android.permission.WRITE_EXTERNAL_STORAGE
adb shell dumpsys deviceidle whitelist +com.ggpark.byddashcam
```

## Ghi hình lên thẻ SD

1. Cắm thẻ SD vào xe (đã format, có quyền ghi).
2. Mở app → Cài đặt → mục **Lưu trữ**.
3. Chọn **Thẻ nhớ SD** trong danh sách ổ.
4. Bản ghi mới sẽ lưu vào thư mục app trên thẻ SD (`Android/data/com.ggpark.byddashcam/.../BYDCamera/recordings`).

## Kiểm thử giả lập

Khi không có camera AVM thật, app tự dùng `FixtureFrameSource` (thanh màu). App chỉ chạy ngang (landscape) — đặt giả lập ở chế độ ngang.

## Cấu trúc dự án

```
src/                  Mã nguồn Java (app trên xe)
phone-ui/             UI web truy cập từ điện thoại (Vite)
mobile/               App điện thoại (Flutter)
res/                  Tài nguyên Android (chuỗi tiếng Việt mặc định)
assets/               Asset tĩnh (kèm bundle phone UI)
stubs/                Stub API AVMCamera (biên dịch)
vendor/               bmmcamera.jar (DEX runtime)
docs/                 Trang landing
build.sh              Script build
```

## Tối ưu hiệu năng (đã áp dụng)

- Frame rate ghi: 25 fps (giảm tải CPU so với 30)
- Khoảng I-frame: 2 giây
- JPEG xem trước điện thoại: chất lượng 60 (mượt hơn trên Wi-Fi xe)
- Nhãn ổ lưu rõ ràng (Thẻ nhớ SD / Bộ nhớ trong + dung lượng trống)

## Giấy phép

MIT
