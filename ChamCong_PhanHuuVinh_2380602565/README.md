# SmartCheck Flutter + ASP.NET Core

Thư mục này chứa ứng dụng Flutter, solution ASP.NET Core 8 và project kiểm thử backend.

- [Tổng quan dự án](../README.md)
- [Hướng dẫn chạy trên máy mới](../HUONG_DAN_CHAY_DU_AN.md)

```powershell
dotnet restore .\ChamCong_PhanHuuVinh_2380602565.slnx
dotnet build .\ChamCong_PhanHuuVinh_2380602565.slnx --no-restore
dotnet test .\ChamCong_PhanHuuVinh_2380602565.slnx --no-build

flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Android Emulator mặc định kết nối `http://10.0.2.2:5262`. Có thể đổi và lưu URL máy chủ trong cài đặt đăng nhập; điện thoại thật dùng IP LAN của máy chạy backend.

Không lưu JWT/OTP key, mật khẩu, Gmail App Password, keystore hoặc `key.properties` trong repository.
