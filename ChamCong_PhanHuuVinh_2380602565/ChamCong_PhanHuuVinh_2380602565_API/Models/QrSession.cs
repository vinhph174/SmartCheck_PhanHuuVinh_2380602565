
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class QrSession
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        // Địa điểm áp dụng mã QR
        public int WorkLocationId { get; set; }

        public WorkLocation WorkLocation { get; set; } = null!;

        // Hash của mã QR, không lưu mã bí mật dạng gốc
        [Required]
        [StringLength(64)]
        public string TokenHash { get; set; } = string.Empty;

        // Mục đích sử dụng: CheckIn hoặc CheckOut
        [Required]
        [StringLength(20)]
        public string Purpose { get; set; } = "CheckIn";

        // Thời gian tạo và hết hạn
        public DateTimeOffset CreatedAtUtc { get; set; }
            = DateTimeOffset.UtcNow;

        public DateTimeOffset ExpiresAtUtc { get; set; }

        // Trạng thái thu hồi mã
        public bool IsRevoked { get; set; } = false;
    }
}
