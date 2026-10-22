
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.DTOs.Auth
{
    public class VerifyEmailRequest
    {
        // Email cần xác minh
        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        public string Email { get; set; } = string.Empty;

        // Mã OTP gồm 6 chữ số
        [Required(ErrorMessage = "Vui lòng nhập OTP")]
        [RegularExpression(
            @"^\d{6}$",
            ErrorMessage = "OTP phải gồm 6 chữ số")]
        public string Code { get; set; } = string.Empty;
    }
}
