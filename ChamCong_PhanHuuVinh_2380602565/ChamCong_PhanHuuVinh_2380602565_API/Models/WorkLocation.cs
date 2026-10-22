
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace ChamCong_PhanHuuVinh_2380602565_API.Models
{
    public class WorkLocation
    {
        public int Id { get; set; }

        [Required]
        [StringLength(150)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [StringLength(300)]
        public string Address { get; set; } = string.Empty;

        [Precision(9, 6)]
        public decimal Latitude { get; set; }

        [Precision(9, 6)]
        public decimal Longitude { get; set; }

        // Bán kính chấm công cho phép (mét)
        public int AllowedRadiusMeters { get; set; } = 100;

        public bool IsActive { get; set; } = true;
    }
}
