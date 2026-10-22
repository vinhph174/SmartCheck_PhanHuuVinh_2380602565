
using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Controllers
{
    [ApiController]
    [Route("api/admin/crud")]
    [Authorize(Roles = "Admin")]
    public class ManagementCrudController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public ManagementCrudController(ApplicationDbContext db)
        {
            _db = db;
        }

        // ========================================
        // CRUD 1 - PHONG BAN
        // ========================================

        // READ - Danh sach
        [HttpGet("departments")]
        public async Task<IActionResult> GetDepartments()
        {
            var data = await _db.Set<Department>()
                .AsNoTracking()
                .OrderBy(x => x.Id)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.Description,
                    x.IsActive
                })
                .ToListAsync();

            return Ok(data);
        }

        // READ - Chi tiet
        [HttpGet("departments/{id:int}")]
        public async Task<IActionResult> GetDepartment(int id)
        {
            var item = await _db.Set<Department>()
                .AsNoTracking()
                .Where(x => x.Id == id)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.Description,
                    x.IsActive
                })
                .FirstOrDefaultAsync();

            return item == null
                ? NotFound(new { message = "Không tìm thấy phòng ban." })
                : Ok(item);
        }

        // CREATE
        [HttpPost("departments")]
        public async Task<IActionResult> CreateDepartment(
            DepartmentCrudRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Name))
                return BadRequest(new
                {
                    message = "Tên phòng ban không được để trống."
                });

            var normalizedName = request.Name.Trim();
            if (await _db.Set<Department>().AnyAsync(x => x.Name == normalizedName))
            {
                return Conflict(new { message = "Tên phòng ban đã tồn tại." });
            }

            var item = new Department
            {
                Name = normalizedName,
                Description = request.Description?.Trim(),
                IsActive = request.IsActive
            };

            _db.Set<Department>().Add(item);
            await _db.SaveChangesAsync();

            return Created(
                $"/api/admin/crud/departments/{item.Id}",
                new { item.Id, item.Name, item.Description, item.IsActive });
        }

        // UPDATE
        [HttpPut("departments/{id:int}")]
        public async Task<IActionResult> UpdateDepartment(
            int id, DepartmentCrudRequest request)
        {
            var item = await _db.Set<Department>().FindAsync(id);

            if (item == null)
                return NotFound(new { message = "Không tìm thấy phòng ban." });

            if (string.IsNullOrWhiteSpace(request.Name))
                return BadRequest(new
                {
                    message = "Tên phòng ban không được để trống."
                });

            var normalizedName = request.Name.Trim();
            if (await _db.Set<Department>().AnyAsync(x =>
                x.Id != id && x.Name == normalizedName))
            {
                return Conflict(new { message = "Tên phòng ban đã tồn tại." });
            }

            item.Name = normalizedName;
            item.Description = request.Description?.Trim();
            item.IsActive = request.IsActive;

            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Cập nhật phòng ban thành công.",
                item.Id
            });
        }

        // DELETE
        [HttpDelete("departments/{id:int}")]
        public async Task<IActionResult> DeleteDepartment(int id)
        {
            var item = await _db.Set<Department>().FindAsync(id);

            if (item == null)
                return NotFound(new { message = "Không tìm thấy phòng ban." });

            _db.Set<Department>().Remove(item);

            try
            {
                await _db.SaveChangesAsync();
                return NoContent();
            }
            catch (DbUpdateException)
            {
                return Conflict(new
                {
                    message = "Không thể xóa phòng ban " +
                              "đang có dữ liệu liên kết."
                });
            }
        }

        // ========================================
        // CRUD 2 - CA LAM VIEC
        // ========================================

        // READ - Danh sach
        [HttpGet("shifts")]
        public async Task<IActionResult> GetShifts()
        {
            var data = await _db.Set<Shift>()
                .AsNoTracking()
                .OrderBy(x => x.Id)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.StartTime,
                    x.EndTime,
                    x.GraceMinutes,
                    x.IsActive
                })
                .ToListAsync();

            return Ok(data);
        }

        // READ - Chi tiet
        [HttpGet("shifts/{id:int}")]
        public async Task<IActionResult> GetShift(int id)
        {
            var item = await _db.Set<Shift>()
                .AsNoTracking()
                .Where(x => x.Id == id)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.StartTime,
                    x.EndTime,
                    x.GraceMinutes,
                    x.IsActive
                })
                .FirstOrDefaultAsync();

            return item == null
                ? NotFound(new { message = "Không tìm thấy ca làm việc." })
                : Ok(item);
        }

        // CREATE
        [HttpPost("shifts")]
        public async Task<IActionResult> CreateShift(
            ShiftCrudRequest request)
        {
            var error = ValidateShift(request);

            if (error != null)
                return BadRequest(new { message = error });

            var normalizedName = request.Name.Trim();
            if (await _db.Set<Shift>().AnyAsync(x => x.Name == normalizedName))
            {
                return Conflict(new { message = "Tên ca làm việc đã tồn tại." });
            }

            var item = new Shift
            {
                Name = normalizedName,
                StartTime = request.StartTime,
                EndTime = request.EndTime,
                GraceMinutes = request.GraceMinutes,
                IsActive = request.IsActive
            };

            _db.Set<Shift>().Add(item);
            await _db.SaveChangesAsync();

            return Created(
                $"/api/admin/crud/shifts/{item.Id}",
                new { item.Id, item.Name, item.StartTime, item.EndTime });
        }

        // UPDATE
        [HttpPut("shifts/{id:int}")]
        public async Task<IActionResult> UpdateShift(
            int id, ShiftCrudRequest request)
        {
            var item = await _db.Set<Shift>().FindAsync(id);

            if (item == null)
                return NotFound(new { message = "Không tìm thấy ca làm việc." });

            var error = ValidateShift(request);

            if (error != null)
                return BadRequest(new { message = error });

            var normalizedName = request.Name.Trim();
            if (await _db.Set<Shift>().AnyAsync(x =>
                x.Id != id && x.Name == normalizedName))
            {
                return Conflict(new { message = "Tên ca làm việc đã tồn tại." });
            }

            item.Name = normalizedName;
            item.StartTime = request.StartTime;
            item.EndTime = request.EndTime;
            item.GraceMinutes = request.GraceMinutes;
            item.IsActive = request.IsActive;

            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Cập nhật ca làm việc thành công.",
                item.Id
            });
        }

        // DELETE
        [HttpDelete("shifts/{id:int}")]
        public async Task<IActionResult> DeleteShift(int id)
        {
            var item = await _db.Set<Shift>().FindAsync(id);

            if (item == null)
                return NotFound(new { message = "Không tìm thấy ca làm việc." });

            _db.Set<Shift>().Remove(item);

            try
            {
                await _db.SaveChangesAsync();
                return NoContent();
            }
            catch (DbUpdateException)
            {
                return Conflict(new
                {
                    message = "Không thể xóa ca làm việc " +
                              "đang có dữ liệu liên kết."
                });
            }
        }

        // ========================================
        // CRUD 3 - DIA DIEM LAM VIEC
        // ========================================

        // READ - Danh sach
        [HttpGet("locations")]
        public async Task<IActionResult> GetLocations()
        {
            var data = await _db.Set<WorkLocation>()
                .AsNoTracking()
                .OrderBy(x => x.Id)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.Address,
                    x.Latitude,
                    x.Longitude,
                    x.AllowedRadiusMeters,
                    x.IsActive
                })
                .ToListAsync();

            return Ok(data);
        }

        // READ - Chi tiet
        [HttpGet("locations/{id:int}")]
        public async Task<IActionResult> GetLocation(int id)
        {
            var item = await _db.Set<WorkLocation>()
                .AsNoTracking()
                .Where(x => x.Id == id)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.Address,
                    x.Latitude,
                    x.Longitude,
                    x.AllowedRadiusMeters,
                    x.IsActive
                })
                .FirstOrDefaultAsync();

            return item == null
                ? NotFound(new { message = "Không tìm thấy địa điểm làm việc." })
                : Ok(item);
        }

        // CREATE
        [HttpPost("locations")]
        public async Task<IActionResult> CreateLocation(
            WorkLocationCrudRequest request)
        {
            var error = ValidateLocation(request);

            if (error != null)
                return BadRequest(new { message = error });

            var normalizedName = request.Name.Trim();
            if (await _db.Set<WorkLocation>().AnyAsync(x => x.Name == normalizedName))
            {
                return Conflict(new { message = "Tên địa điểm đã tồn tại." });
            }

            var item = new WorkLocation
            {
                Name = normalizedName,
                Address = request.Address.Trim(),
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                AllowedRadiusMeters = request.AllowedRadiusMeters,
                IsActive = request.IsActive
            };

            _db.Set<WorkLocation>().Add(item);
            await _db.SaveChangesAsync();

            return Created(
                $"/api/admin/crud/locations/{item.Id}",
                new { item.Id, item.Name, item.Address });
        }

        // UPDATE
        [HttpPut("locations/{id:int}")]
        public async Task<IActionResult> UpdateLocation(
            int id, WorkLocationCrudRequest request)
        {
            var item = await _db.Set<WorkLocation>().FindAsync(id);

            if (item == null)
                return NotFound(new { message = "Không tìm thấy địa điểm làm việc." });

            var error = ValidateLocation(request);

            if (error != null)
                return BadRequest(new { message = error });

            var normalizedName = request.Name.Trim();
            if (await _db.Set<WorkLocation>().AnyAsync(x =>
                x.Id != id && x.Name == normalizedName))
            {
                return Conflict(new { message = "Tên địa điểm đã tồn tại." });
            }

            item.Name = normalizedName;
            item.Address = request.Address.Trim();
            item.Latitude = request.Latitude;
            item.Longitude = request.Longitude;
            item.AllowedRadiusMeters = request.AllowedRadiusMeters;
            item.IsActive = request.IsActive;

            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Cập nhật địa điểm làm việc thành công.",
                item.Id
            });
        }

        // DELETE
        [HttpDelete("locations/{id:int}")]
        public async Task<IActionResult> DeleteLocation(int id)
        {
            var item =
                await _db.Set<WorkLocation>().FindAsync(id);

            if (item == null)
                return NotFound(new { message = "Không tìm thấy địa điểm làm việc." });

            _db.Set<WorkLocation>().Remove(item);

            try
            {
                await _db.SaveChangesAsync();
                return NoContent();
            }
            catch (DbUpdateException)
            {
                return Conflict(new
                {
                    message = "Không thể xóa địa điểm làm việc " +
                              "đang có dữ liệu liên kết."
                });
            }
        }

        // ========================================
        // VALIDATION
        // ========================================

        private static string? ValidateShift(ShiftCrudRequest x)
        {
            if (string.IsNullOrWhiteSpace(x.Name))
                return "Tên ca làm việc không được để trống.";

            if (x.StartTime < TimeSpan.Zero ||
                x.StartTime >= TimeSpan.FromDays(1) ||
                x.EndTime < TimeSpan.Zero ||
                x.EndTime >= TimeSpan.FromDays(1))
                return "Giờ làm việc không hợp lệ.";

            if (x.StartTime == x.EndTime)
                return "Giờ bắt đầu và kết thúc phải khác nhau.";

            if (x.GraceMinutes < 0 || x.GraceMinutes > 120)
                return "Số phút cho phép phải từ 0 đến 120.";

            return null;
        }

        private static string? ValidateLocation(
            WorkLocationCrudRequest x)
        {
            if (string.IsNullOrWhiteSpace(x.Name) ||
                string.IsNullOrWhiteSpace(x.Address))
                return "Tên và địa chỉ không được để trống.";

            if (x.Latitude < -90 || x.Latitude > 90)
                return "Vĩ độ không hợp lệ.";

            if (x.Longitude < -180 || x.Longitude > 180)
                return "Kinh độ không hợp lệ.";

            if (x.AllowedRadiusMeters <= 0 ||
                x.AllowedRadiusMeters > 5000)
                return "Bán kính phải từ 1 đến 5000 mét.";

            return null;
        }
    }

    // ========================================
    // DTO PHONG BAN
    // ========================================

    public class DepartmentCrudRequest
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        public bool IsActive { get; set; } = true;
    }

    // ========================================
    // DTO CA LAM VIEC
    // ========================================

    public class ShiftCrudRequest
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        public TimeSpan StartTime { get; set; }

        public TimeSpan EndTime { get; set; }

        public int GraceMinutes { get; set; } = 10;

        public bool IsActive { get; set; } = true;
    }

    // ========================================
    // DTO DIA DIEM LAM VIEC
    // ========================================

    public class WorkLocationCrudRequest
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [Required]
        [StringLength(300)]
        public string Address { get; set; } = string.Empty;

        public decimal Latitude { get; set; }

        public decimal Longitude { get; set; }

        public int AllowedRadiusMeters { get; set; } = 200;

        public bool IsActive { get; set; } = true;
    }
}
