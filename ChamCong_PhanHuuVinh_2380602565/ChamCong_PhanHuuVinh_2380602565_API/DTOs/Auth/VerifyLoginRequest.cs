
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.DTOs.Auth
{
    public class VerifyLoginRequest
    {
        [Required]
        public string UserName { get; set; } = string.Empty;

        [Required]
        [RegularExpression(@"^\d{6}$")]
        public string Code { get; set; } = string.Empty;

        // Bang chung da qua buoc kiem tra mat khau
        [Required]
        public string LoginTicket { get; set; } = string.Empty;
    }
}
