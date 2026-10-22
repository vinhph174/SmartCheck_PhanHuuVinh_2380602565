# Hướng dẫn chạy SmartCheck trên máy mới

Các lệnh dưới đây bắt đầu tại repository root. Không chạy migration trên database đang có dữ liệu nếu chưa sao lưu và chưa được chủ sở hữu cho phép.

## 1. Chuẩn bị công cụ

Cài .NET SDK 8, Flutter hỗ trợ Dart 3.13.4, Java 17, Android SDK và SQL Server Express:

```powershell
dotnet --info
flutter doctor -v
java -version
```

Nếu chưa có EF Core CLI:

```powershell
dotnet tool install --global dotnet-ef --version 8.*
```

## 2. Chuẩn bị SQL Server trên database mới

Backend mặc định dùng instance `.\SQLEXPRESS`, Windows Authentication và database `ChamCong_PhanHuuVinh_2380602565`. Kiểm tra instance bằng SQL Server Configuration Manager hoặc SSMS. Nếu môi trường khác, đặt connection string bằng User Secrets thay vì ghi credential vào source:

```powershell
Set-Location .\ChamCong_PhanHuuVinh_2380602565\ChamCong_PhanHuuVinh_2380602565_API
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "<CONNECTION_STRING_RIENG>"
```

Chỉ với database mới hoặc khi đã được phép áp dụng schema:

```powershell
dotnet ef database update
```

Migration không tạo sẵn nhân viên, phòng ban, ca, địa điểm hay lịch sử chấm công. Tạo dữ liệu nghiệp vụ qua giao diện Admin sau khi hệ thống chạy.

## 3. Cấu hình User Secrets

Trong thư mục API, sinh hai khóa độc lập:

```powershell
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

JWT và OTP không dùng chung khóa. Đặt email gửi OTP, Gmail App Password và bootstrap Admin bằng giá trị riêng:

```powershell
dotnet user-secrets set "Email:SmtpUser" "<EMAIL_GUI_OTP>"
dotnet user-secrets set "Email:SmtpPassword" "<GMAIL_APP_PASSWORD>"
dotnet user-secrets set "AdminBootstrap:Enabled" "true"
dotnet user-secrets set "AdminBootstrap:UserName" "<TEN_DANG_NHAP_ADMIN>"
dotnet user-secrets set "AdminBootstrap:Email" "<EMAIL_ADMIN_NHAN_DUOC_OTP>"
dotnet user-secrets set "AdminBootstrap:Password" "<MAT_KHAU_MANH_RIENG>"
```

Khởi động API một lần để tạo Admin đầu tiên, rồi tắt bootstrap:

```powershell
dotnet user-secrets set "AdminBootstrap:Enabled" "false"
```

Không đưa User Secrets, App Password, JWT/OTP key lên GitHub. Nếu các giá trị trong tài liệu cũ đã được sử dụng, hãy rotate thủ công tại môi trường tương ứng.

## 4. Khôi phục, build và test backend

```powershell
Set-Location ..
dotnet restore .\ChamCong_PhanHuuVinh_2380602565.slnx
dotnet build .\ChamCong_PhanHuuVinh_2380602565.slnx --no-restore
dotnet test .\ChamCong_PhanHuuVinh_2380602565.slnx --no-build
```

Test backend dùng EF Core InMemory và không ghi SQL Server. Đây không phải SQL Server integration test.

## 5. Chạy backend

```powershell
Set-Location .\ChamCong_PhanHuuVinh_2380602565_API
dotnet run --urls http://0.0.0.0:5262
```

Kiểm tra trên máy chạy API:

- Swagger Development: `http://127.0.0.1:5262/swagger`.
- Process health: `http://127.0.0.1:5262/health`.

Không công khai cổng API ra Internet. Binding `0.0.0.0` chỉ dùng khi cần thiết bị cùng LAN truy cập và phải kết hợp firewall phù hợp.

## 6. Khôi phục và chạy Flutter

Mở PowerShell thứ hai tại repository root:

```powershell
Set-Location .\ChamCong_PhanHuuVinh_2380602565
flutter pub get
flutter analyze
flutter test
flutter run
```

Trong cài đặt máy chủ tại màn hình đăng nhập:

- Emulator dùng `http://10.0.2.2:5262`.
- Điện thoại thật dùng `http://<IP-LAN-MAY-TINH>:5262`.

Điện thoại và máy tính phải cùng LAN; cho phép cổng 5262 trong Windows Firewall cho mạng Private nếu cần. Không dùng `127.0.0.1` trên điện thoại vì đó là chính điện thoại.

## 7. Luồng sử dụng ban đầu

1. Admin đăng nhập username/password và OTP gửi đến email Admin.
2. Employee đăng ký và xác minh email qua OTP.
3. Admin kích hoạt Employee.
4. Admin tạo phòng ban, địa điểm, ca làm và phân ca qua giao diện.
5. Employee đăng nhập hai bước, quét QR động và cấp quyền Camera/GPS khi chấm công.

QR có hiệu lực 120 giây. Mỗi lần xác nhận chấm công lấy GPS mới; nếu GPS tắt, quyền bị từ chối hoặc hết thời gian chờ thì không gửi tọa độ cũ.

## 8. OTP/SMTP và lỗi thường gặp

- HTTP 503 khi gửi OTP: kiểm tra Internet, `Email:SmtpUser`, Gmail App Password, cổng 587 và User Secrets.
- Không nhận OTP: kiểm tra Spam, địa chỉ email và đồng hồ hệ thống; không ghi OTP ra log để chẩn đoán.
- 401 sau khi vô hiệu hóa tài khoản: hành vi đúng; backend kiểm tra trạng thái tài khoản tại mỗi lần xác thực JWT.
- Emulator không kết nối: xác nhận API nghe cổng 5262 và dùng `10.0.2.2`, không dùng `localhost`.
- Release không gọi được HTTP: triển khai API HTTPS đáng tin cậy.

## 9. Build Android

```powershell
Set-Location ..
flutter build apk --debug
flutter build apk --release
```

Debug phù hợp demo HTTP cục bộ. Release cần API HTTPS và keystore phát hành riêng; hiện tại dùng debug signing chỉ để xác minh build đồ án. Không commit keystore, `key.properties`, APK hay AAB.
