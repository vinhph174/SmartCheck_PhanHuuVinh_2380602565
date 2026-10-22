using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;
using ChamCong_PhanHuuVinh_2380602565_API.Services;

namespace ChamCong_PhanHuuVinh_2380602565_API.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/appeals")]
    public class AttendanceAppealsController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public AttendanceAppealsController(ApplicationDbContext db)
        {
            _db = db;
        }

        // ========================================
        // 1. NHAN VIEN GUI GIAI TRINH CHAM CONG
        // ========================================

        [HttpPost]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> CreateAppeal(
            [FromBody] CreateAppealRequest request)
        {
            var reasonError = AppealReasonPolicy.Validate(request.Reason);
            if (reasonError != null)
            {
                return BadRequest(new { message = reasonError });
            }

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

            // Ca lam viec phai thuoc ve nhan vien nay
            var assignment = await _db.Set<ShiftAssignment>()
                .Include(s => s.Shift)
                .FirstOrDefaultAsync(s =>
                    s.Id == request.ShiftAssignmentId &&
                    s.EmployeeId == employee.Id);

            if (assignment == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy ca làm việc tương ứng của bạn."
                });
            }

            // Kiem tra da co giai trinh dang cho duyet cho ca nay chua
            var blockingStatus = await _db.Set<AttendanceAppeal>()
                .Where(a =>
                    a.ShiftAssignmentId == request.ShiftAssignmentId &&
                    (a.Status == "Pending" || a.Status == "Approved"))
                .Select(a => a.Status)
                .FirstOrDefaultAsync();

            if (blockingStatus != null)
            {
                return Conflict(new
                {
                    message = blockingStatus == "Approved"
                        ? "Ca làm việc này đã có yêu cầu giải trình được duyệt."
                        : "Ca làm việc này đã có yêu cầu giải trình đang chờ duyệt."
                });
            }

            var appeal = new AttendanceAppeal
            {
                EmployeeId = employee.Id,
                ShiftAssignmentId = request.ShiftAssignmentId,
                Reason = request.Reason.Trim(),
                Status = "Pending",
                SubmittedAtUtc = DateTimeOffset.UtcNow
            };

            _db.Set<AttendanceAppeal>().Add(appeal);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Gửi yêu cầu giải trình thành công.",
                appealId = appeal.Id,
                status = appeal.Status,
                submittedAtUtc = appeal.SubmittedAtUtc
            });
        }

        // ========================================
        // 2. NHAN VIEN XEM GIAI TRINH CUA MINH
        // ========================================

        [HttpGet("my")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> GetMyAppeals()
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
                return NotFound(new { message = "Không tìm thấy hồ sơ nhân viên." });

            var items = await _db.Set<AttendanceAppeal>()
                .AsNoTracking()
                .Where(a => a.EmployeeId == employee.Id)
                .OrderByDescending(a => a.SubmittedAtUtc)
                .Select(a => new
                {
                    a.Id,
                    a.ShiftAssignmentId,
                    WorkDate = a.ShiftAssignment.WorkDate,
                    ShiftName = a.ShiftAssignment.Shift.Name,
                    LocationName = a.ShiftAssignment.WorkLocation.Name,
                    a.Reason,
                    a.Status,
                    a.ReviewNote,
                    a.SubmittedAtUtc,
                    a.ReviewedAtUtc
                })
                .ToListAsync();

            return Ok(new
            {
                total = items.Count,
                appeals = items
            });
        }

        // ========================================
        // 2.1. NHAN VIEN - GOI Y GIAI TRINH THONG MINH
        // ========================================

        [HttpGet("suggestions")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> GetAppealSuggestions()
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
                return NotFound(new { message = "Không tìm thấy hồ sơ nhân viên." });

            var now = VietnamTime.Now;
            var today = DateOnly.FromDateTime(now.DateTime);
            var thirtyDaysAgo = today.AddDays(-30);

            // Cac ca da co don giai trinh dang cho duyet hoac da duyet
            var appealedShiftIds = await _db.Set<AttendanceAppeal>()
                .Where(a => a.EmployeeId == employee.Id && a.Status != "Rejected")
                .Select(a => a.ShiftAssignmentId)
                .ToListAsync();

            // Tim cac ca co bat thuong trong 30 ngay gan nhat
            var anomalousAssignments = await _db.Set<ShiftAssignment>()
                .AsNoTracking()
                .Include(s => s.Shift)
                .Include(s => s.WorkLocation)
                .Include(s => s.AttendanceRecord)
                .Where(s => s.EmployeeId == employee.Id &&
                            s.WorkDate >= thirtyDaysAgo &&
                            !appealedShiftIds.Contains(s.Id))
                .OrderByDescending(s => s.WorkDate)
                .ToListAsync();

            var suggestions = new List<object>();

            foreach (var a in anomalousAssignments)
            {
                // Thoi diem ket thuc ca thuc te: ca qua dem (EndTime < StartTime) se ket thuc vao ngay hom sau
                var shiftEndDateTime = VietnamTime.GetShiftEnd(
                    a.WorkDate,
                    a.Shift.StartTime,
                    a.Shift.EndTime);

                var isPastShift = now.DateTime > shiftEndDateTime;

                if (a.AttendanceRecord?.CheckInStatus == "Late")
                {
                    suggestions.Add(new
                    {
                        shiftAssignmentId = a.Id,
                        workDate = a.WorkDate,
                        shiftName = a.Shift.Name,
                        locationName = a.WorkLocation.Name,
                        anomalyType = "LateCheckIn",
                        anomalyDescription = "Vào ca muộn so với quy định",
                        suggestedReason = $"Tôi xin giải trình về trường hợp vào ca muộn trong ca {a.Shift.Name} ngày {a.WorkDate:dd/MM/yyyy}. Lý do thực tế: "
                    });
                }
                else if (a.Status == "InProgress" && isPastShift)
                {
                    suggestions.Add(new
                    {
                        shiftAssignmentId = a.Id,
                        workDate = a.WorkDate,
                        shiftName = a.Shift.Name,
                        locationName = a.WorkLocation.Name,
                        anomalyType = "MissingCheckOut",
                        anomalyDescription = "Chưa hoàn tất chấm công ra ca",
                        suggestedReason = $"Tôi xin giải trình về trường hợp chưa hoàn tất chấm công ra trong ca {a.Shift.Name} ngày {a.WorkDate:dd/MM/yyyy}. Lý do thực tế: "
                    });
                }
                else if (a.Status == "Scheduled" && isPastShift)
                {
                    suggestions.Add(new
                    {
                        shiftAssignmentId = a.Id,
                        workDate = a.WorkDate,
                        shiftName = a.Shift.Name,
                        locationName = a.WorkLocation.Name,
                        anomalyType = "MissedShift",
                        anomalyDescription = "Vắng mặt ca làm việc chưa chấm công",
                        suggestedReason = $"Tôi xin giải trình về trường hợp vắng mặt trong ca {a.Shift.Name} ngày {a.WorkDate:dd/MM/yyyy}. Lý do thực tế: "
                    });
                }
            }

            return Ok(new
            {
                total = suggestions.Count,
                suggestions
            });
        }

        // ========================================
        // 3. ADMIN XEM TAT CA GIAI TRINH
        // ========================================

        [HttpGet]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAllAppeals(
            [FromQuery] string? status)
        {
            var query = _db.Set<AttendanceAppeal>()
                .AsNoTracking()
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(a => a.Status == status.Trim());
            }

            var items = await query
                .OrderByDescending(a => a.SubmittedAtUtc)
                .Select(a => new
                {
                    a.Id,
                    a.EmployeeId,
                    EmployeeCode = a.Employee.EmployeeCode,
                    EmployeeName = a.Employee.ApplicationUser.FullName,
                    DepartmentName = a.Employee.Department != null
                        ? a.Employee.Department.Name : null,
                    a.ShiftAssignmentId,
                    WorkDate = a.ShiftAssignment.WorkDate,
                    ShiftName = a.ShiftAssignment.Shift.Name,
                    LocationName = a.ShiftAssignment.WorkLocation.Name,
                    a.Reason,
                    a.Status,
                    a.ReviewNote,
                    ReviewedBy = a.ReviewedByUser != null
                        ? a.ReviewedByUser.FullName : null,
                    a.SubmittedAtUtc,
                    a.ReviewedAtUtc
                })
                .ToListAsync();

            return Ok(new
            {
                total = items.Count,
                appeals = items
            });
        }

        // ========================================
        // 4. ADMIN PHE DUYET / TU CHOI GIAI TRINH
        // ========================================

        [HttpPut("{id:long}/review")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> ReviewAppeal(
            long id,
            [FromBody] ReviewAppealRequest request)
        {
            if (request.Status != "Approved" && request.Status != "Rejected")
            {
                return BadRequest(new
                {
                    message = "Trạng thái xét duyệt không hợp lệ."
                });
            }

            var appeal = await _db.Set<AttendanceAppeal>()
                .FirstOrDefaultAsync(a => a.Id == id);

            if (appeal == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy yêu cầu giải trình."
                });
            }

            if (appeal.Status != "Pending")
            {
                return Conflict(new
                {
                    message = "Yêu cầu giải trình này đã được xử lý trước đó."
                });
            }

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            appeal.Status = request.Status;
            appeal.ReviewNote = request.ReviewNote?.Trim();
            appeal.ReviewedByUserId = userId;
            appeal.ReviewedAtUtc = DateTimeOffset.UtcNow;

            try
            {
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                return Conflict(new
                {
                    message = "Yêu cầu giải trình vừa được quản trị viên khác xử lý."
                });
            }

            return Ok(new
            {
                message = "Đã xử lý giải trình thành công.",
                appealId = appeal.Id,
                status = appeal.Status,
                reviewedAtUtc = appeal.ReviewedAtUtc
            });
        }
    }

    public class CreateAppealRequest
    {
        [Range(1, int.MaxValue)]
        public int ShiftAssignmentId { get; set; }

        [Required]
        [StringLength(1000, MinimumLength = 5)]
        public string Reason { get; set; } = string.Empty;
    }

    public class ReviewAppealRequest
    {
        [Required]
        public string Status { get; set; } = string.Empty;

        [StringLength(1000)]
        public string? ReviewNote { get; set; }
    }
}

