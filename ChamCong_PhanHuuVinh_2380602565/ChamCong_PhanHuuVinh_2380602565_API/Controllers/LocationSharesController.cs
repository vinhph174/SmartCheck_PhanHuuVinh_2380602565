using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/location-shares")]
    public class LocationSharesController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public LocationSharesController(ApplicationDbContext db)
        {
            _db = db;
        }

        // ========================================
        // 1. NHAN VIEN GUI TOA DO CHIA SE VI TRI
        // ========================================

        [HttpPost]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> ShareLocation(
            [FromBody] LocationShareRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var employee = await _db.Set<Employee>()
                .AsNoTracking()
                .FirstOrDefaultAsync(e =>
                    e.ApplicationUserId == userId &&
                    e.IsActive &&
                    e.ApplicationUser.IsActive);

            if (employee == null)
                return Forbid();

            if (request.Latitude < -90 || request.Latitude > 90 ||
                request.Longitude < -180 || request.Longitude > 180)
            {
                return BadRequest(new { message = "Tọa độ GPS không hợp lệ." });
            }

            if (request.AccuracyMeters.HasValue &&
                (double.IsNaN(request.AccuracyMeters.Value) ||
                 double.IsInfinity(request.AccuracyMeters.Value) ||
                 request.AccuracyMeters.Value < 0 ||
                 request.AccuracyMeters.Value > 10000))
            {
                return BadRequest(new { message = "Độ chính xác GPS không hợp lệ." });
            }

            var record = new LocationShare
            {
                EmployeeId = employee.Id,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                AccuracyMeters = request.AccuracyMeters,
                SharedAtUtc = DateTimeOffset.UtcNow,
                Note = request.Note?.Trim()
            };

            _db.Set<LocationShare>().Add(record);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Chia sẻ vị trí thành công.",
                id = record.Id,
                sharedAtUtc = record.SharedAtUtc
            });
        }

        // ========================================
        // 2. ADMIN XEM VI TRI MOI NHAT CUA CAC NHAN VIEN
        // ========================================

        [HttpGet("latest")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetLatestLocations()
        {
            // Lay tat ca nhan vien va vi tri chia se moi nhat cua ho
            var employees = await _db.Set<Employee>()
                .AsNoTracking()
                .Where(e => e.IsActive && e.ApplicationUser.IsActive)
                .Select(e => new
                {
                    employeeId = e.Id,
                    employeeCode = e.EmployeeCode,
                    fullName = e.ApplicationUser.FullName,
                    departmentName = e.Department != null ? e.Department.Name : null,
                    latestLocation = _db.Set<LocationShare>()
                        .Where(l => l.EmployeeId == e.Id)
                        .OrderByDescending(l => l.SharedAtUtc)
                        .Select(l => new
                        {
                            l.Id,
                            l.Latitude,
                            l.Longitude,
                            l.AccuracyMeters,
                            l.SharedAtUtc,
                            l.Note
                        })
                        .FirstOrDefault()
                })
                .ToListAsync();

            var sharedList = employees
                .Where(x => x.latestLocation != null)
                .OrderByDescending(x => x.latestLocation!.SharedAtUtc)
                .ToList();

            return Ok(new
            {
                total = sharedList.Count,
                items = sharedList
            });
        }

        // ========================================
        // 3. NHAN VIEN XEM LICH SU CHIA SE CUA MINH
        // ========================================

        [HttpGet("my")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> GetMyHistory([FromQuery] int limit = 20)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var employee = await _db.Set<Employee>()
                .AsNoTracking()
                .FirstOrDefaultAsync(e => e.ApplicationUserId == userId);

            if (employee == null)
                return NotFound(new { message = "Không tìm thấy nhân viên." });

            var items = await _db.Set<LocationShare>()
                .AsNoTracking()
                .Where(l => l.EmployeeId == employee.Id)
                .OrderByDescending(l => l.SharedAtUtc)
                .Take(Math.Clamp(limit, 1, 100))
                .Select(l => new
                {
                    l.Id,
                    l.Latitude,
                    l.Longitude,
                    l.AccuracyMeters,
                    l.SharedAtUtc,
                    l.Note
                })
                .ToListAsync();

            return Ok(new
            {
                total = items.Count,
                items
            });
        }
    }

    public class LocationShareRequest
    {
        [Range(typeof(decimal), "-90", "90")]
        public decimal Latitude { get; set; }

        [Range(typeof(decimal), "-180", "180")]
        public decimal Longitude { get; set; }

        public double? AccuracyMeters { get; set; }

        [StringLength(250)]
        public string? Note { get; set; }
    }
}

