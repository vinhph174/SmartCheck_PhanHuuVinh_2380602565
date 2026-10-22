
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
    [Route("api/shift-assignments")]
    public class ShiftAssignmentsController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public ShiftAssignmentsController(ApplicationDbContext db)
        {
            _db = db;
        }

        // ========================================
        // 1. ADMIN - DANH SACH PHAN CONG CA
        // ========================================

        [HttpGet]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAll(
            [FromQuery] int? employeeId,
            [FromQuery] DateOnly? workDate)
        {
            var query = _db.Set<ShiftAssignment>()
                .AsNoTracking()
                .AsQueryable();

            if (employeeId.HasValue)
            {
                query = query.Where(x =>
                    x.EmployeeId == employeeId.Value);
            }

            if (workDate.HasValue)
            {
                query = query.Where(x =>
                    x.WorkDate == workDate.Value);
            }

            var data = await query
                .OrderBy(x => x.WorkDate)
                .ThenBy(x => x.Shift.StartTime)
                .Select(x => new
                {
                    x.Id,

                    x.EmployeeId,
                    x.Employee.EmployeeCode,
                    EmployeeName =
                        x.Employee.ApplicationUser.FullName,

                    x.ShiftId,
                    ShiftName = x.Shift.Name,
                    x.Shift.StartTime,
                    x.Shift.EndTime,

                    x.WorkLocationId,
                    LocationName = x.WorkLocation.Name,

                    x.WorkDate,
                    x.Status,

                    HasAttendance =
                        x.AttendanceRecord != null
                })
                .ToListAsync();

            return Ok(new
            {
                total = data.Count,
                assignments = data
            });
        }

        // ========================================
        // 2. EMPLOYEE - LICH LAM VIEC CUA MINH
        // ========================================

        [HttpGet("my")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> GetMyAssignments()
        {
            // Lay UserId tu JWT
            var userId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(userId))
            {
                return Unauthorized();
            }

            // Tim ho so nhan vien cua tai khoan
            var employee = await _db.Set<Employee>()
                .AsNoTracking()
                .Where(x => x.ApplicationUserId == userId)
                .Select(x => new
                {
                    x.Id,
                    x.IsActive,
                    AccountActive = x.ApplicationUser.IsActive
                })
                .FirstOrDefaultAsync();

            if (employee == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy hồ sơ nhân viên."
                });
            }

            if (!employee.IsActive || !employee.AccountActive)
            {
                return Forbid();
            }

            // Chi lay lich cua nhan vien dang dang nhap
            var data = await _db.Set<ShiftAssignment>()
                .AsNoTracking()
                .Where(x => x.EmployeeId == employee.Id)
                .OrderBy(x => x.WorkDate)
                .ThenBy(x => x.Shift.StartTime)
                .Select(x => new
                {
                    x.Id,
                    x.WorkDate,
                    x.Status,

                    x.ShiftId,
                    ShiftName = x.Shift.Name,
                    x.Shift.StartTime,
                    x.Shift.EndTime,
                    x.Shift.GraceMinutes,

                    x.WorkLocationId,
                    LocationName = x.WorkLocation.Name,
                    LocationAddress = x.WorkLocation.Address,
                    x.WorkLocation.Latitude,
                    x.WorkLocation.Longitude,
                    x.WorkLocation.AllowedRadiusMeters,

                    HasAttendance =
                        x.AttendanceRecord != null
                })
                .ToListAsync();

            return Ok(new
            {
                employeeId = employee.Id,
                total = data.Count,
                assignments = data
            });
        }

        // ========================================
        // 3. ADMIN - CHI TIET PHAN CONG
        // ========================================

        [HttpGet("{id:int}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetById(int id)
        {
            var item = await _db.Set<ShiftAssignment>()
                .AsNoTracking()
                .Where(x => x.Id == id)
                .Select(x => new
                {
                    x.Id,
                    x.EmployeeId,
                    x.Employee.EmployeeCode,
                    EmployeeName =
                        x.Employee.ApplicationUser.FullName,

                    x.ShiftId,
                    ShiftName = x.Shift.Name,
                    x.Shift.StartTime,
                    x.Shift.EndTime,

                    x.WorkLocationId,
                    LocationName = x.WorkLocation.Name,

                    x.WorkDate,
                    x.Status,

                    HasAttendance =
                        x.AttendanceRecord != null
                })
                .FirstOrDefaultAsync();

            if (item == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy phân công ca."
                });
            }

            return Ok(item);
        }

        // ========================================
        // 4. ADMIN - TAO PHAN CONG CA
        // ========================================

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create(
            ShiftAssignmentRequest request)
        {
            // Kiem tra du lieu dau vao
            if (request.WorkDate == default)
            {
                return BadRequest(new
                {
                    message = "Ngày làm việc không hợp lệ."
                });
            }

            var error = await ValidateReferencesAsync(request);

            if (error != null)
            {
                return BadRequest(new { message = error });
            }

            // Mot nhan vien khong duoc nhan
            // trung cung ca trong cung ngay
            var duplicate = await _db.Set<ShiftAssignment>()
                .AnyAsync(x =>
                    x.EmployeeId == request.EmployeeId &&
                    x.ShiftId == request.ShiftId &&
                    x.WorkDate == request.WorkDate);

            if (duplicate)
            {
                return Conflict(new
                {
                    message =
                        "Nhân viên đã được phân công " +
                        "ca này trong ngày."
                });
            }

            var item = new ShiftAssignment
            {
                EmployeeId = request.EmployeeId,
                ShiftId = request.ShiftId,
                WorkLocationId = request.WorkLocationId,
                WorkDate = request.WorkDate,
                Status = "Scheduled"
            };

            _db.Set<ShiftAssignment>().Add(item);

            await _db.SaveChangesAsync();

            return CreatedAtAction(
                nameof(GetById),
                new { id = item.Id },
                new
                {
                    message = "Phân công ca thành công.",
                    item.Id,
                    item.EmployeeId,
                    item.ShiftId,
                    item.WorkLocationId,
                    item.WorkDate,
                    item.Status
                });
        }

        // ========================================
        // 5. ADMIN - CAP NHAT PHAN CONG
        // ========================================

        [HttpPut("{id:int}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(
            int id,
            ShiftAssignmentRequest request)
        {
            var item = await _db.Set<ShiftAssignment>()
                .FirstOrDefaultAsync(x => x.Id == id);

            if (item == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy phân công ca."
                });
            }

            if (item.Status != "Scheduled")
            {
                return Conflict(new
                {
                    message =
                        "Chỉ được sửa phân công đang ở trạng thái đã lên lịch."
                });
            }

            // Khong sua ca da phat sinh cham cong
            var hasAttendance =
                await _db.Set<AttendanceRecord>()
                    .AnyAsync(x => x.ShiftAssignmentId == id);

            if (hasAttendance)
            {
                return Conflict(new
                {
                    message =
                        "Không thể sửa ca đã có dữ liệu chấm công."
                });
            }

            if (request.WorkDate == default)
            {
                return BadRequest(new
                {
                    message = "Ngày làm việc không hợp lệ."
                });
            }

            var error = await ValidateReferencesAsync(request);

            if (error != null)
            {
                return BadRequest(new { message = error });
            }

            // Kiem tra trung phan cong
            var duplicate = await _db.Set<ShiftAssignment>()
                .AnyAsync(x =>
                    x.Id != id &&
                    x.EmployeeId == request.EmployeeId &&
                    x.ShiftId == request.ShiftId &&
                    x.WorkDate == request.WorkDate);

            if (duplicate)
            {
                return Conflict(new
                {
                    message =
                        "Phân công ca bị trùng."
                });
            }

            item.EmployeeId = request.EmployeeId;
            item.ShiftId = request.ShiftId;
            item.WorkLocationId = request.WorkLocationId;
            item.WorkDate = request.WorkDate;

            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Cập nhật phân công thành công.",
                item.Id
            });
        }

        // ========================================
        // 6. ADMIN - XOA PHAN CONG
        // ========================================

        [HttpDelete("{id:int}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var item = await _db.Set<ShiftAssignment>()
                .FirstOrDefaultAsync(x => x.Id == id);

            if (item == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy phân công ca."
                });
            }

            if (item.Status != "Scheduled")
            {
                return Conflict(new
                {
                    message =
                        "Chỉ được xóa phân công đang ở trạng thái đã lên lịch."
                });
            }

            // Bao ve du lieu cham cong
            var hasAttendance =
                await _db.Set<AttendanceRecord>()
                    .AnyAsync(x => x.ShiftAssignmentId == id);

            if (hasAttendance)
            {
                return Conflict(new
                {
                    message =
                        "Không thể xóa ca đã chấm công."
                });
            }

            _db.Set<ShiftAssignment>().Remove(item);

            try
            {
                await _db.SaveChangesAsync();
                return NoContent();
            }
            catch (DbUpdateException)
            {
                return Conflict(new
                {
                    message =
                        "Không thể xóa phân công do " +
                        "có dữ liệu liên kết."
                });
            }
        }

        // ========================================
        // 7. KIEM TRA NHAN VIEN - CA - DIA DIEM
        // ========================================

        private async Task<string?> ValidateReferencesAsync(
            ShiftAssignmentRequest request)
        {
            var validEmployee = await _db.Set<Employee>()
                .AnyAsync(x =>
                    x.Id == request.EmployeeId &&
                    x.IsActive &&
                    x.ApplicationUser.IsActive &&
                    x.ApplicationUser.EmailConfirmed);

            if (!validEmployee)
            {
                return "Nhân viên không tồn tại " +
                       "hoặc chưa được kích hoạt.";
            }

            var validShift = await _db.Set<Shift>()
                .AnyAsync(x =>
                    x.Id == request.ShiftId &&
                    x.IsActive);

            if (!validShift)
            {
                return "Ca làm việc không tồn tại " +
                       "hoặc đã bị vô hiệu hóa.";
            }

            var validLocation =
                await _db.Set<WorkLocation>()
                    .AnyAsync(x =>
                        x.Id == request.WorkLocationId &&
                        x.IsActive);

            if (!validLocation)
            {
                return "Địa điểm làm việc không tồn tại " +
                       "hoặc đã bị vô hiệu hóa.";
            }

            return null;
        }
    }

    // ========================================
    // DTO - DU LIEU PHAN CONG CA
    // ========================================

    public class ShiftAssignmentRequest
    {
        [Range(1, int.MaxValue)]
        public int EmployeeId { get; set; }

        [Range(1, int.MaxValue)]
        public int ShiftId { get; set; }

        [Range(1, int.MaxValue)]
        public int WorkLocationId { get; set; }

        public DateOnly WorkDate { get; set; }
    }
}
