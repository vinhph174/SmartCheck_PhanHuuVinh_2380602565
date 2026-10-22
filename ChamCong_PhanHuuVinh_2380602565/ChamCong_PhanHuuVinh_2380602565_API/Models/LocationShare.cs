
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class LocationShare
    {
        public long Id { get; set; }

        // Nhân viên chia sẻ vị trí
        public int EmployeeId { get; set; }

        public Employee Employee { get; set; } = null!;

        // Tọa độ GPS
        [Precision(9, 6)]
        public decimal Latitude { get; set; }

        [Precision(9, 6)]
        public decimal Longitude { get; set; }

        // Độ chính xác GPS (mét)
        public double? AccuracyMeters { get; set; }

        // Thời gian chia sẻ
        public DateTimeOffset SharedAtUtc { get; set; }
            = DateTimeOffset.UtcNow;

        [StringLength(250)]
        public string? Note { get; set; }
    }
}
