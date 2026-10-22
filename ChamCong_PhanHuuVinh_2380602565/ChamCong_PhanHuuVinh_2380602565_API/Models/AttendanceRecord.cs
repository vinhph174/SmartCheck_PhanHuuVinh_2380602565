
using Microsoft.EntityFrameworkCore;
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class AttendanceRecord
    {
        public long Id { get; set; }

        // Liên kết ca làm được phân công
        public int ShiftAssignmentId { get; set; }

        public ShiftAssignment ShiftAssignment
        {
            get; set;
        } = null!;

        // Thời gian chấm công do Server ghi nhận
        public DateTimeOffset? CheckInUtc { get; set; }

        public DateTimeOffset? CheckOutUtc { get; set; }

        // Vị trí khi chấm công vào
        [Precision(9, 6)]
        public decimal? CheckInLatitude { get; set; }

        [Precision(9, 6)]
        public decimal? CheckInLongitude { get; set; }

        // Vị trí khi chấm công ra
        [Precision(9, 6)]
        public decimal? CheckOutLatitude { get; set; }

        [Precision(9, 6)]
        public decimal? CheckOutLongitude { get; set; }

        // Mã QR được xác minh
        public Guid? CheckInQrSessionId { get; set; }

        public Guid? CheckOutQrSessionId { get; set; }

        // Trạng thái chấm công
        [StringLength(30)]
        public string? CheckInStatus { get; set; }
    }
}
