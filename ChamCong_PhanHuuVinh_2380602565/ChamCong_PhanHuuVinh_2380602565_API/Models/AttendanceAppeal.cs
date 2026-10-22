
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class AttendanceAppeal
    {
        public long Id { get; set; }

        // Nhân viên gửi giải trình
        public int EmployeeId { get; set; }

        public Employee Employee { get; set; } = null!;

        // Ca làm cần giải trình
        public int ShiftAssignmentId { get; set; }

        public ShiftAssignment ShiftAssignment { get; set; }
            = null!;

        // Lý do giải trình
        [Required]
        [StringLength(1000)]
        public string Reason { get; set; } = string.Empty;

        // Pending, Approved hoặc Rejected
        [Required]
        [StringLength(20)]
        public string Status { get; set; } = "Pending";

        // Nhận xét của người duyệt
        [StringLength(1000)]
        public string? ReviewNote { get; set; }

        public string? ReviewedByUserId { get; set; }

        public ApplicationUser? ReviewedByUser { get; set; }

        // Thời gian gửi và duyệt
        public DateTimeOffset SubmittedAtUtc { get; set; }
            = DateTimeOffset.UtcNow;

        public DateTimeOffset? ReviewedAtUtc { get; set; }
    }
}
