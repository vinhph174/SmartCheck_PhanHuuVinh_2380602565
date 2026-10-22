
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.DTOs.Auth
{
    public class LoginRequest
    {
        // Ten tai khoan dang nhap
        [Required(ErrorMessage = "Vui lòng nhập tên đăng nhập")]
        public string UserName { get; set; } = string.Empty;

        // Mat khau dang nhap
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
        public string Password { get; set; } = string.Empty;
    }
}
