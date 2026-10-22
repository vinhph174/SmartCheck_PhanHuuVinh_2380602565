
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class OtpChallenge
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        // Tài khoản cần xác thực
        [Required]
        public string ApplicationUserId { get; set; }
            = string.Empty;

        public ApplicationUser ApplicationUser { get; set; }
            = null!;

        // Giá trị xác minh OTP được lưu dưới dạng mã bảo vệ
        [Required]
        [StringLength(128)]
        public string CodeHash { get; set; } = string.Empty;

        // Login hoặc VerifyEmail
        [Required]
        [StringLength(30)]
        public string Purpose { get; set; } = "Login";

        public DateTimeOffset CreatedAtUtc { get; set; }
            = DateTimeOffset.UtcNow;

        public DateTimeOffset ExpiresAtUtc { get; set; }

        public DateTimeOffset? ConsumedAtUtc { get; set; }

        // Số lần thử nhập OTP
        public int AttemptCount { get; set; } = 0;
    }
}
