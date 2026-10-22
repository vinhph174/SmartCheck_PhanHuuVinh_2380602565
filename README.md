# SmartCheck — Chấm Công Thông Minh

Đồ án môn Lập trình thiết bị di động của **Phan Hữu Vinh — MSSV 2380602565**.

SmartCheck gồm ứng dụng Flutter cho Android, ASP.NET Core 8 Web API và SQL Server Express. Hệ thống hỗ trợ đăng ký/xác minh email, đăng nhập hai bước bằng OTP, phân quyền Admin/Employee, quản lý dữ liệu chấm công, QR động 120 giây, kiểm tra khoảng cách GPS, cảm biến chuyển động và trợ lý gợi ý giải trình.

> QR, GPS và cảm biến giúp tăng độ tin cậy nhưng không phải cam kết chống gian lận tuyệt đối.

## Cấu trúc repository

```text
.
├── README.md
├── HUONG_DAN_CHAY_DU_AN.md
├── .gitignore
├── .github/                         # modernize/ là metadata cục bộ được ignore
└── ChamCong_PhanHuuVinh_2380602565/
    ├── lib/                         # Flutter source
    ├── test/                        # Flutter unit/widget tests
    ├── android/
    ├── pubspec.yaml
    ├── ChamCong_PhanHuuVinh_2380602565.slnx
    ├── ChamCong_PhanHuuVinh_2380602565_API/
    │   ├── Controllers/
    │   ├── Data/
    │   ├── Migrations/
    │   └── Services/
    └── ChamCong_PhanHuuVinh_2380602565_API.Tests/
```

Repository root phù hợp để đưa lên GitHub là thư mục chứa file README này. Không tạo repository riêng bên trong thư mục Flutter.

## Yêu cầu môi trường

- .NET SDK 8.x.
- Flutter tương thích Dart `^3.13.4`; môi trường đã xác minh dùng Flutter 3.47.5 / Dart 3.13.4.
- Java 17 và Android SDK do Flutter yêu cầu.
- SQL Server Express cho môi trường chạy thật.
- EF Core CLI 8.x nếu cần áp dụng migration trên database mới.

```powershell
dotnet --version
flutter --version
flutter doctor -v
java -version
dotnet ef --version
```

## Bắt đầu nhanh

Từ repository root:

```powershell
dotnet restore .\ChamCong_PhanHuuVinh_2380602565\ChamCong_PhanHuuVinh_2380602565.slnx
dotnet build .\ChamCong_PhanHuuVinh_2380602565\ChamCong_PhanHuuVinh_2380602565.slnx --no-restore
dotnet test .\ChamCong_PhanHuuVinh_2380602565\ChamCong_PhanHuuVinh_2380602565.slnx --no-build

Set-Location .\ChamCong_PhanHuuVinh_2380602565
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Quy trình SQL Server, User Secrets, OTP/SMTP và thiết bị nằm trong [HUONG_DAN_CHAY_DU_AN.md](HUONG_DAN_CHAY_DU_AN.md).

## Cấu hình bí mật

Backend không lưu JWT key, OTP key, Gmail App Password hay mật khẩu quản trị trong source. Dùng .NET User Secrets tại thư mục API:

```powershell
Set-Location .\ChamCong_PhanHuuVinh_2380602565\ChamCong_PhanHuuVinh_2380602565_API
dotnet user-secrets init

$jwtBytes = New-Object byte[] 64
[Security.Cryptography.RandomNumberGenerator]::Fill($jwtBytes)
$jwtKey = [Convert]::ToBase64String($jwtBytes)
dotnet user-secrets set "Jwt:Key" $jwtKey
Remove-Variable jwtBytes,jwtKey

$otpBytes = New-Object byte[] 64
[Security.Cryptography.RandomNumberGenerator]::Fill($otpBytes)
$otpKey = [Convert]::ToBase64String($otpBytes)
dotnet user-secrets set "Otp:Key" $otpKey
Remove-Variable otpBytes,otpKey
```

JWT và OTP phải dùng hai khóa sinh độc lập. Đặt các giá trị sau bằng dữ liệu riêng của người triển khai; không commit chúng:

```powershell
dotnet user-secrets set "Email:SmtpUser" "<EMAIL_GUI_OTP>"
dotnet user-secrets set "Email:SmtpPassword" "<GMAIL_APP_PASSWORD>"
dotnet user-secrets set "AdminBootstrap:UserName" "<TEN_DANG_NHAP_RIENG>"
dotnet user-secrets set "AdminBootstrap:Email" "<EMAIL_ADMIN_NHAN_DUOC_OTP>"
dotnet user-secrets set "AdminBootstrap:Password" "<MAT_KHAU_MANH_RIENG>"
dotnet user-secrets set "AdminBootstrap:Enabled" "true"
```

Sau lần tạo Admin đầu tiên, đặt `AdminBootstrap:Enabled` về `false`. Không dùng mật khẩu mẫu cố định giữa các máy.

> Nếu các giá trị từng xuất hiện trong README cũ đã được dùng cho môi trường thật hoặc demo, chủ sở hữu phải rotate JWT key, OTP key, Gmail App Password và mật khẩu Admin. Việc này không được tự động hóa vì có thể làm mất phiên hoặc gián đoạn demo.

## Kết nối ứng dụng

- Android Emulator: `http://10.0.2.2:5262`.
- API trên cùng máy: `http://127.0.0.1:5262`.
- Điện thoại Android thật: `http://<IP-LAN-MAY-TINH>:5262`.

URL máy chủ đổi được trong màn hình cài đặt đăng nhập và được lưu lại. Ứng dụng chỉ chấp nhận URL `http`/`https` không chứa username, password, query hay fragment.

HTTP cleartext chỉ được bật trong Android Debug manifest để demo nội bộ. Bản Release cần API HTTPS hợp lệ; không bật cleartext toàn cục cho Release.

## Luồng tài khoản

1. Employee đăng ký bằng email.
2. Employee nhập OTP nhận qua email để xác minh.
3. Admin kích hoạt hồ sơ Employee.
4. Người dùng đăng nhập username/password, sau đó xác minh OTP.
5. JWT được lưu bằng Android Keystore qua `flutter_secure_storage`; logout, token hết hạn hoặc HTTP 401 sẽ xóa phiên.

Không có tài khoản hoặc mật khẩu demo cố định trong repository.

## Kiểm thử đã xác minh

- Backend: 66 test, EF Core InMemory/direct controller unit tests.
- Flutter: 33 unit/widget tests.
- Không dùng kết quả này để khẳng định đã integration-test SQL Server Express.
- Không gửi OTP thật và không thay đổi database SQL Server chính trong đợt hoàn thiện.

Hãy chạy lại kiểm thử trên mỗi máy hoặc commit mới.

## Giới hạn triển khai

- Release Android hiện dùng debug signing config để phục vụ đồ án; cần keystore phát hành riêng trước khi phân phối thực tế. Không commit keystore hoặc `key.properties`.
- Swagger chỉ bật trong Development. Health endpoint: `GET /health`.
- SMTP lỗi thường trả 503; kiểm tra mạng, tài khoản gửi, Gmail App Password và User Secrets.
- Migrations tạo schema; không tự tạo dữ liệu nghiệp vụ mẫu như phòng ban, ca làm hay lịch sử chấm công.
