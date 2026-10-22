
using Microsoft.AspNetCore.Identity;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class ApplicationUser : IdentityUser
    {
        // Họ tên người dùng
        public string FullName { get; set; } = string.Empty;

        // Trạng thái tài khoản
        public bool IsActive { get; set; } = false;

        // Ngày tạo tài khoản theo giờ UTC
        public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    }
}
