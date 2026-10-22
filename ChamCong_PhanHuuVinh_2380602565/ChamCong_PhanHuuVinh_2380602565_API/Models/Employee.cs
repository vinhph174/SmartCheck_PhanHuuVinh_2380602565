
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class Employee
    {
        public int Id { get; set; }

        [Required]
        [StringLength(30)]
        public string EmployeeCode { get; set; } = string.Empty;

        // Liên kết tài khoản Identity
        [Required]
        public string ApplicationUserId { get; set; }
            = string.Empty;

        public ApplicationUser ApplicationUser { get; set; }
            = null!;

        // Phòng ban có thể chưa được phân công
        public int? DepartmentId { get; set; }

        public Department? Department { get; set; }

        public DateTime? HireDate { get; set; }

        public bool IsActive { get; set; } = true;
    }
}
