
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.DTOs.Auth
{
    public class RegisterRequest
    {
        // Họ tên người đăng ký
        [Required(ErrorMessage = "Vui lòng nhập họ tên")]
        [StringLength(100, MinimumLength = 2)]
        public string FullName { get; set; } = string.Empty;

        // Tên đăng nhập
        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
        [StringLength(50, MinimumLength = 3)]
        public string UserName { get; set; } = string.Empty;

        // Email đăng ký
        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        public string Email { get; set; } = string.Empty;

        // Mật khẩu
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
        [MinLength(8)]
        public string Password { get; set; } = string.Empty;
    }
}
