
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class ShiftAssignment
    {
        public int Id { get; set; }

        // Nhân viên được phân công
        public int EmployeeId { get; set; }

        public Employee Employee { get; set; } = null!;

        // Ca làm việc
        public int ShiftId { get; set; }

        public Shift Shift { get; set; } = null!;

        // Địa điểm làm việc
        public int WorkLocationId { get; set; }

        public WorkLocation WorkLocation { get; set; }
            = null!;

        // Ngày làm việc
        public DateOnly WorkDate { get; set; }

        // Trạng thái phân ca
        [Required]
        [StringLength(30)]
        public string Status { get; set; } = "Scheduled";

        // Mỗi phân ca có tối đa 1 bản ghi chấm công
        public AttendanceRecord? AttendanceRecord
        {
            get; set;
        }
    }
}
