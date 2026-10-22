
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class Shift
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        // Giờ bắt đầu ca
        public TimeSpan StartTime { get; set; }

        // Giờ kết thúc ca
        public TimeSpan EndTime { get; set; }

        // Số phút cho phép đến muộn
        public int GraceMinutes { get; set; } = 5;

        public bool IsActive { get; set; } = true;
    }
}
