
using System.ComponentModel.DataAnnotations;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class Department
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        public bool IsActive { get; set; } = true;

        // Một phòng ban có nhiều nhân viên
        public ICollection<Employee> Employees { get; set; }
            = new List<Employee>();
    }
}
