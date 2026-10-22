
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.DTOs.Auth;
using ChamCong_PhanHuuVinh_2380602565_API.Models;
using ChamCong_PhanHuuVinh_2380602565_API.Services;

namespace ChamCong_PhanHuuVinh_2380602565_API.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _users;
        private readonly ApplicationDbContext _db;
        private readonly IOtpService _otp;
        private readonly IEmailService _email;
        private readonly IConfiguration _config;
        private readonly ILogger<AuthController> _logger;
        private readonly ITimeLimitedDataProtector _loginProtector;

        public AuthController(
            UserManager<ApplicationUser> users,
            ApplicationDbContext db,
            IOtpService otp,
            IEmailService email,
            IConfiguration config,
            ILogger<AuthController> logger,
            IDataProtectionProvider protectionProvider)
        {
            _users = users;
            _db = db;
            _otp = otp;
            _email = email;
            _config = config;
            _logger = logger;

            // Bao ve LoginTicket tam thoi
            _loginProtector = protectionProvider
                .CreateProtector("SmartCheck.LoginStep.v1")
                .ToTimeLimitedDataProtector();
        }

        // ========================================
        // 1. DANG KY TAI KHOAN
        // ========================================

        [HttpPost("register")]
        public async Task<IActionResult> Register(
            RegisterRequest request)
        {
            var email = request.Email.Trim();
            var userName = request.UserName.Trim();

            // Kiem tra email hoac username da ton tai
            if (await _users.FindByEmailAsync(email) != null ||
                await _users.FindByNameAsync(userName) != null)
            {
                return Conflict(new
                {
                    message = "Email hoặc tên đăng nhập đã tồn tại."
                });
            }

            // Tao tai khoan chua xac minh
            var user = new ApplicationUser
            {
                UserName = userName,
                Email = email,
                FullName = request.FullName.Trim(),
                EmailConfirmed = false,
                IsActive = false,
                CreatedAtUtc = DateTime.UtcNow
            };

            // Tao tai khoan, role va ho so nhan vien
            // trong mot giao dich SQL Server
            await using (var transaction =
                await _db.Database.BeginTransactionAsync())
            {
                var created = await _users.CreateAsync(
                    user, request.Password);

                if (!created.Succeeded)
                {
                    return BadRequest(new
                    {
                        errors = created.Errors
                            .Select(e => e.Description)
                    });
                }

                // Nguoi dung dang ky chi nhan role Employee
                var roleResult = await _users.AddToRoleAsync(
                    user, "Employee");

                if (!roleResult.Succeeded)
                {
                    return StatusCode(500, new
                    {
                        message = "Không thể gán vai trò Nhân viên."
                    });
                }

                // Tao ma nhan vien ngau nhien
                var employeeCode = "NV" +
                    Guid.NewGuid()
                        .ToString("N")[..16]
                        .ToUpperInvariant();

                var employee = new Employee
                {
                    ApplicationUserId = user.Id,
                    EmployeeCode = employeeCode,
                    DepartmentId = null,
                    IsActive = false
                };

                _db.Set<Employee>().Add(employee);

                await _db.SaveChangesAsync();
                await transaction.CommitAsync();
            }

            // Tao va gui OTP xac minh email
            try
            {
                var code = await _otp.CreateAsync(
                    user.Id, "VerifyEmail");

                await _email.SendEmailAsync(
                    email,
                    "Chấm Công Thông Minh - Xác minh email",
                    $"Mã OTP của bạn là: {code}\n" +
                    "Mã có hiệu lực trong 5 phút.");

                return Ok(new
                {
                    message = "Đăng ký thành công. " +
                              "Vui lòng kiểm tra email để lấy OTP."
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Khong gui duoc OTP dang ky.");

                // Tai khoan da duoc tao.
                // Nguoi dung co the xin gui lai OTP.
                return StatusCode(503, new
                {
                    accountCreated = true,
                    message = "Tài khoản đã được tạo " +
                              "nhưng chưa gửi được OTP. " +
                              "Vui lòng gửi lại mã xác minh."
                });
            }
        }

        // ========================================
        // 2. XAC MINH EMAIL BANG OTP
        // ========================================

        [HttpPost("verify-email")]
        public async Task<IActionResult> VerifyEmail(
            VerifyEmailRequest request)
        {
            var user = await _users.FindByEmailAsync(
                request.Email.Trim());

            if (user == null || user.EmailConfirmed)
            {
                return BadRequest(new
                {
                    message = "Yêu cầu xác minh không hợp lệ."
                });
            }

            // Kiem tra OTP trong database
            var valid = await _otp.VerifyAsync(
                user.Id, "VerifyEmail", request.Code);

            if (!valid)
            {
                return BadRequest(new
                {
                    message = "OTP sai, hết hạn hoặc đã được sử dụng."
                });
            }

            // Danh dau email da duoc xac minh
            user.EmailConfirmed = true;

            var result = await _users.UpdateAsync(user);

            if (!result.Succeeded)
            {
                return StatusCode(500, new
                {
                    message = "Không thể cập nhật trạng thái email."
                });
            }

            return Ok(new
            {
                message = "Xác minh email thành công. " +
                          "Tài khoản đang chờ quản trị viên kích hoạt."
            });
        }

        // ========================================
        // 3. GUI LAI OTP XAC MINH EMAIL
        // ========================================

        [HttpPost("resend-verification-otp")]
        public async Task<IActionResult> ResendVerificationOtp(
            ResendVerificationRequest request)
        {
            var email = request.Email.Trim();

            // Thong bao chung, tranh tiet lo
            // email da dang ky hay chua
            var message =
                "Nếu email đã đăng ký và chưa xác minh, " +
                "hệ thống sẽ gửi mã OTP.";

            var user = await _users.FindByEmailAsync(email);

            // Khong gui neu user khong ton tai
            // hoac email da duoc xac minh
            if (user == null || user.EmailConfirmed)
            {
                return Ok(new { message });
            }

            string code;

            try
            {
                // Tao OTP moi trong SQL Server.
                // OtpService kiem tra gioi han yeu cau.
                code = await _otp.CreateAsync(
                    user.Id, "VerifyEmail");
            }
            catch (InvalidOperationException ex)
                when (
                    ex.Message.StartsWith(
                        "Đã vượt giới hạn cấp OTP") ||
                    ex.Message.StartsWith(
                        "Vui lòng đợi 60 giây"))
            {
                _logger.LogInformation(
                    "Gioi han cap OTP cho tai khoan {UserId}",
                    user.Id);

                // Phan hoi chung de khong tiet lo
                // email co ton tai hay khong
                return Ok(new { message });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Khong tao duoc OTP cho tai khoan {UserId}",
                    user.Id);

                return StatusCode(503, new
                {
                    message = "Dịch vụ OTP tạm thời không khả dụng."
                });
            }

            try
            {
                // Gui OTP moi qua Gmail SMTP
                await _email.SendEmailAsync(
                    user.Email!,
                    "Chấm Công Thông Minh - Gửi lại OTP",
                    $"Mã OTP xác minh email: {code}\n" +
                    "Mã có hiệu lực trong 5 phút.");

                return Ok(new { message });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Khong gui duoc OTP cho tai khoan {UserId}",
                    user.Id);

                return StatusCode(503, new
                {
                    message = "Dịch vụ email tạm thời không khả dụng."
                });
            }
        }

        // ========================================
        // 4. DANG NHAP USERNAME + PASSWORD
        // ========================================

        [HttpPost("login")]
        public async Task<IActionResult> Login(
            LoginRequest request)
        {
            var user = await _users.FindByNameAsync(
                request.UserName.Trim());

            // Tu choi user khong ton tai hoac bi khoa
            if (user == null ||
                await _users.IsLockedOutAsync(user))
            {
                return Unauthorized(new
                {
                    message = "Thông tin đăng nhập không hợp lệ."
                });
            }

            // Kiem tra mat khau
            var correctPassword = await _users
                .CheckPasswordAsync(user, request.Password);

            if (!correctPassword)
            {
                await _users.AccessFailedAsync(user);

                return Unauthorized(new
                {
                    message = "Thông tin đăng nhập không hợp lệ."
                });
            }

            // Kiem tra email, trang thai, role
            if (!await CanLoginAsync(user))
            {
                return StatusCode(403, new
                {
                    message = "Tài khoản chưa đủ điều kiện đăng nhập."
                });
            }

                        string code;
            try
            {
                // Tao OTP dang nhap
                code = await _otp.CreateAsync(
                    user.Id, "Login");
            }
            catch (InvalidOperationException ex)
                when (ex.Message.StartsWith("Đã vượt giới hạn cấp OTP") ||
                      ex.Message.StartsWith("Vui lòng đợi 60 giây"))
            {
                _logger.LogWarning(
                    "Gioi han cap OTP cho user {UserId}: {Message}",
                    user.Id, ex.Message);

                return StatusCode(429, new
                {
                    message = ex.Message
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Khong the tao OTP dang nhap cho user {UserId}.",
                    user.Id);

                return StatusCode(500, new
                {
                    message = "Lỗi hệ thống khi tạo OTP đăng nhập."
                });
            }

            try
            {
                // Gui OTP qua email
                await _email.SendEmailAsync(
                    user.Email!,
                    "Chấm Công Thông Minh - OTP đăng nhập",
                    $"Mã đăng nhập của bạn là: {code}\n" +
                    "Mã có hiệu lực trong 5 phút.");

                // Tao LoginTicket sau khi mat khau dung
                var ticket = _loginProtector.Protect(
                    user.Id,
                    TimeSpan.FromMinutes(5));

                return Ok(new
                {
                    message = "Đã gửi OTP đăng nhập.",
                    loginTicket = ticket,
                    expiresInSeconds = 300
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "Khong gui duoc email OTP dang nhap cho user {UserId}.",
                    user.Id);

                return StatusCode(503, new
                {
                    message = "Không thể gửi email OTP lúc này. Vui lòng thử lại sau."
                });
            }
        }

        // ========================================
        // 5. XAC MINH OTP DANG NHAP VA CAP JWT
        // ========================================

        [HttpPost("verify-login")]
        public async Task<IActionResult> VerifyLogin(
            VerifyLoginRequest request)
        {
            string ticketUserId;

            try
            {
                // Giai ma LoginTicket.
                // Ticket het han hoac gia mao se bi tu choi.
                ticketUserId = _loginProtector.Unprotect(
                    request.LoginTicket);
            }
            catch (CryptographicException)
            {
                return Unauthorized(new
                {
                    message = "Phiên đăng nhập đã hết hạn " +
                              "hoặc không hợp lệ."
                });
            }

            var user = await _users.FindByNameAsync(
                request.UserName.Trim());

            // Ticket phai thuoc dung tai khoan
            if (user == null ||
                user.Id != ticketUserId ||
                !await CanLoginAsync(user))
            {
                return Unauthorized(new
                {
                    message = "Phiên đăng nhập không hợp lệ."
                });
            }

            // Xac minh OTP dang nhap
            var valid = await _otp.VerifyAsync(
                user.Id, "Login", request.Code);

            if (!valid)
            {
                return Unauthorized(new
                {
                    message = "OTP sai, hết hạn hoặc đã được sử dụng."
                });
            }

            // Dat lai bo dem nhap sai
            await _users.ResetAccessFailedCountAsync(user);

            var roles = await _users.GetRolesAsync(user);

            // Tao JWT sau khi xac minh OTP
            var accessToken = CreateJwt(user, roles);

            var expiryMinutes = _config.GetValue(
                "Jwt:ExpiryMinutes", 30);

            return Ok(new
            {
                accessToken,
                tokenType = "Bearer",
                expiresInSeconds = expiryMinutes * 60,
                role = roles.Contains("Admin")
                    ? "Admin"
                    : "Employee",
                userName = user.UserName,
                fullName = user.FullName
            });
        }

        // ========================================
        // 6. KIEM TRA DIEU KIEN DANG NHAP
        // ========================================

        private async Task<bool> CanLoginAsync(
            ApplicationUser user)
        {
            // Email phai duoc xac minh
            // Tai khoan phai hoat dong
            // Tai khoan khong bi khoa
            if (!user.EmailConfirmed ||
                !user.IsActive ||
                await _users.IsLockedOutAsync(user))
            {
                return false;
            }

            var roles = await _users.GetRolesAsync(user);

            if (!roles.Contains("Admin") &&
                !roles.Contains("Employee"))
            {
                return false;
            }

            // Employee phai co ho so dang hoat dong
            if (roles.Contains("Employee"))
            {
                var employeeIsActive =
                    await _db.Set<Employee>().AnyAsync(
                        e => e.ApplicationUserId == user.Id
                          && e.IsActive);

                if (!employeeIsActive)
                {
                    return false;
                }
            }

            return true;
        }

        // ========================================
        // 7. TAO JWT ACCESS TOKEN
        // ========================================

        private string CreateJwt(
            ApplicationUser user,
            IList<string> roles)
        {
            var issuer = _config["Jwt:Issuer"]
                ?? throw new InvalidOperationException(
                    "Thiếu Jwt:Issuer");

            var audience = _config["Jwt:Audience"]
                ?? throw new InvalidOperationException(
                    "Thiếu Jwt:Audience");

            var keyText = _config["Jwt:Key"]
                ?? throw new InvalidOperationException(
                    "Thiếu Jwt:Key");

            var key = new SymmetricSecurityKey(
                Convert.FromBase64String(keyText));

            // Claims cua JWT
            var claims = new List<Claim>
            {
                new Claim(
                    ClaimTypes.NameIdentifier,
                    user.Id),

                new Claim(
                    ClaimTypes.Name,
                    user.UserName ?? string.Empty),

                new Claim(
                    JwtRegisteredClaimNames.Jti,
                    Guid.NewGuid().ToString("N"))
            };

            // Them cac role vao JWT
            foreach (var role in roles)
            {
                claims.Add(new Claim(
                    ClaimTypes.Role,
                    role));
            }

            // Thoi han JWT
            var expires = DateTime.UtcNow.AddMinutes(
                _config.GetValue("Jwt:ExpiryMinutes", 30));

            var jwt = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                notBefore: DateTime.UtcNow,
                expires: expires,
                signingCredentials: new SigningCredentials(
                    key,
                    SecurityAlgorithms.HmacSha256));

            return new JwtSecurityTokenHandler()
                .WriteToken(jwt);
        }
    }
}
