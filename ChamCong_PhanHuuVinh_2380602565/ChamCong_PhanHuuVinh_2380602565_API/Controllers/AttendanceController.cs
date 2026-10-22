
using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

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
    [Route("api/attendance")]
    public class AttendanceController : ControllerBase
    {
        private readonly ApplicationDbContext _db;

        public AttendanceController(ApplicationDbContext db)
        {
            _db = db;
        }

        // ========================================
        // 1. ADMIN TAO MA QR CHAM CONG
        // ========================================

        [HttpPost("qr-session")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> CreateQrSession(
            CreateAttendanceQrRequest request)
        {
            if (request.Purpose != "CheckIn" &&
                request.Purpose != "CheckOut")
            {
                return BadRequest(new
                {
                    message = "Mục đích chấm công không hợp lệ."
                });
            }

            var location = await _db.Set<WorkLocation>()
                .FirstOrDefaultAsync(x =>
                    x.Id == request.WorkLocationId &&
                    x.IsActive);

            if (location == null)
            {
                return NotFound(new
                {
                    message = "Địa điểm không tồn tại hoặc đã bị khóa."
                });
            }

            // Token ngau nhien 32 byte
            var token = Convert.ToHexString(
                RandomNumberGenerator.GetBytes(32));

            // Chi luu SHA256 trong database
            var hash = Convert.ToHexString(
                SHA256.HashData(
                    Encoding.UTF8.GetBytes(token)));

            var now = DateTimeOffset.UtcNow;

            var session = new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = location.Id,
                TokenHash = hash,
                Purpose = request.Purpose,
                CreatedAtUtc = now,
                ExpiresAtUtc = now.AddMinutes(2),
                IsRevoked = false
            };

            _db.Set<QrSession>().Add(session);
            await _db.SaveChangesAsync();

            return Ok(new
            {
                sessionId = session.Id,
                locationName = location.Name,
                purpose = session.Purpose,

                // Noi dung Flutter se hien thi thanh QR
                qrPayload = "SC1:" + token,

                expiresAtUtc = session.ExpiresAtUtc,
                expiresInSeconds = 120
            });
        }

        // ========================================
        // 2. NHAN VIEN XEM LICH SU CHAM CONG
        // ========================================

        [HttpGet("my")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> GetMyAttendance()
        {
            var userId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(userId))
                return Unauthorized();

            var employee = await _db.Set<Employee>()
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.ApplicationUserId == userId &&
                    x.IsActive &&
                    x.ApplicationUser.IsActive);

            if (employee == null)
                return Forbid();

            var records = await _db.Set<AttendanceRecord>()
                .AsNoTracking()
                .Where(x =>
                    x.ShiftAssignment.EmployeeId == employee.Id)
                .OrderByDescending(x =>
                    x.ShiftAssignment.WorkDate)
                .Select(x => new
                {
                    x.Id,
                    x.ShiftAssignmentId,
                    x.ShiftAssignment.WorkDate,
                    ShiftName = x.ShiftAssignment.Shift.Name,
                    LocationName =
                        x.ShiftAssignment.WorkLocation.Name,
                    x.CheckInUtc,
                    x.CheckOutUtc,
                    x.CheckInStatus
                })
                .ToListAsync();

            return Ok(new
            {
                employeeId = employee.Id,
                total = records.Count,
                records
            });
        }

        // ========================================
        // 3. EMPLOYEE CHECK-IN
        // ========================================

        [HttpPost("check-in")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> CheckIn(
            AttendanceActionRequest request)
        {
            var assignment = await GetOwnedAssignmentAsync(
                request.ShiftAssignmentId);

            if (assignment == null)
                return NotFound(new
                {
                    message = "Không tìm thấy ca làm việc được phân công."
                });

            if (!IsActiveEmployee(assignment))
                return Forbid();

            if (assignment.Status != "Scheduled")
                return Conflict(new
                {
                    message = "Ca làm việc không ở trạng thái đã lên lịch."
                });

            var localNow = VietnamTime.Now;

            var today = DateOnly.FromDateTime(
                localNow.DateTime);

            if (assignment.WorkDate != today)
                return Conflict(new
                {
                    message = "Hôm nay không phải ngày của ca làm việc này."
                });

            var locationError = ValidateLocation(
                request, assignment.WorkLocation);

            if (locationError != null)
                return BadRequest(new
                {
                    message = locationError
                });

            var qr = await FindValidQrAsync(
                request.QrPayload,
                assignment.WorkLocationId,
                "CheckIn");

            if (qr == null)
                return BadRequest(new
                {
                    message = "Mã QR không hợp lệ hoặc đã hết hạn."
                });

            var existing = await _db.Set<AttendanceRecord>()
                .AnyAsync(x =>
                    x.ShiftAssignmentId == assignment.Id);

            if (existing)
                return Conflict(new
                {
                    message = "Ca làm việc này đã có bản ghi chấm công."
                });

            var now = DateTimeOffset.UtcNow;

            var shiftStart = assignment.WorkDate
                .ToDateTime(TimeOnly.MinValue)
                .Add(assignment.Shift.StartTime);

            var isLate = localNow.DateTime >
                shiftStart.AddMinutes(
                    assignment.Shift.GraceMinutes);

            var record = new AttendanceRecord
            {
                ShiftAssignmentId = assignment.Id,
                CheckInUtc = now,
                CheckInQrSessionId = qr.Id,
                CheckInLatitude = request.Latitude,
                CheckInLongitude = request.Longitude,
                CheckInStatus = isLate ? "Late" : "OnTime"
            };

            _db.Set<AttendanceRecord>().Add(record);

            assignment.Status = "InProgress";

            try
            {
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                return Conflict(new
                {
                    message = "Không thể lưu chấm công vào. " +
                              "Vui lòng kiểm tra ca đã được chấm công hay chưa."
                });
            }

            return Ok(new
            {
                message = "Chấm công vào thành công.",
                attendanceId = record.Id,
                checkInUtc = record.CheckInUtc,
                status = record.CheckInStatus
            });
        }

        // ========================================
        // 4. EMPLOYEE CHECK-OUT
        // ========================================

        [HttpPost("check-out")]
        [Authorize(Roles = "Employee")]
        public async Task<IActionResult> CheckOut(
            AttendanceActionRequest request)
        {
            var assignment = await GetOwnedAssignmentAsync(
                request.ShiftAssignmentId);

            if (assignment == null)
                return NotFound(new
                {
                    message = "Không tìm thấy ca làm việc được phân công."
                });

            if (!IsActiveEmployee(assignment))
                return Forbid();

            if (assignment.Status != "InProgress")
                return Conflict(new
                {
                    message = "Ca làm việc chưa được chấm công vào hoặc đã kết thúc."
                });

            var locationError = ValidateLocation(
                request, assignment.WorkLocation);

            if (locationError != null)
                return BadRequest(new
                {
                    message = locationError
                });

            var qr = await FindValidQrAsync(
                request.QrPayload,
                assignment.WorkLocationId,
                "CheckOut");

            if (qr == null)
                return BadRequest(new
                {
                    message = "Mã QR chấm công ra không hợp lệ hoặc đã hết hạn."
                });

            var record = await _db.Set<AttendanceRecord>()
                .FirstOrDefaultAsync(x =>
                    x.ShiftAssignmentId == assignment.Id);

            if (record == null || record.CheckInUtc == null)
                return Conflict(new
                {
                    message = "Nhân viên chưa chấm công vào."
                });

            if (record.CheckOutUtc != null)
                return Conflict(new
                {
                    message = "Nhân viên đã chấm công ra."
                });

            var now = DateTimeOffset.UtcNow;

            if (now <= record.CheckInUtc.Value)
                return Conflict(new
                {
                    message = "Thời gian chấm công ra không hợp lệ."
                });

            record.CheckOutUtc = now;
            record.CheckOutQrSessionId = qr.Id;
            record.CheckOutLatitude = request.Latitude;
            record.CheckOutLongitude = request.Longitude;

            assignment.Status = "Completed";

            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Chấm công ra thành công.",
                attendanceId = record.Id,
                checkInUtc = record.CheckInUtc,
                checkOutUtc = record.CheckOutUtc
            });
        }

        // ========================================
        // 5. TIM CA THUOC NHAN VIEN DANG NHAP
        // ========================================

        private async Task<ShiftAssignment?>
            GetOwnedAssignmentAsync(int id)
        {
            var userId = User.FindFirstValue(
                ClaimTypes.NameIdentifier);

            if (string.IsNullOrWhiteSpace(userId))
                return null;

            return await _db.Set<ShiftAssignment>()
                .Include(x => x.Employee)
                    .ThenInclude(x => x.ApplicationUser)
                .Include(x => x.Shift)
                .Include(x => x.WorkLocation)
                .FirstOrDefaultAsync(x =>
                    x.Id == id &&
                    x.Employee.ApplicationUserId == userId);
        }

        private static bool IsActiveEmployee(
            ShiftAssignment assignment)
        {
            return assignment.Employee.IsActive &&
                   assignment.Employee.ApplicationUser.IsActive &&
                   assignment.Employee.ApplicationUser.EmailConfirmed &&
                   assignment.Shift.IsActive &&
                   assignment.WorkLocation.IsActive;
        }

        // ========================================
        // 6. KIEM TRA QR TRONG DATABASE
        // ========================================

        private async Task<QrSession?> FindValidQrAsync(
            string payload,
            int locationId,
            string purpose)
        {
            if (string.IsNullOrWhiteSpace(payload) ||
                !payload.StartsWith(
                    "SC1:", StringComparison.Ordinal))
            {
                return null;
            }

            var token = payload[4..];

            if (token.Length != 64 ||
                !token.All(Uri.IsHexDigit))
            {
                return null;
            }

            var hash = Convert.ToHexString(
                SHA256.HashData(
                    Encoding.UTF8.GetBytes(token)));

            var now = DateTimeOffset.UtcNow;

            return await _db.Set<QrSession>()
                .AsNoTracking()
                .FirstOrDefaultAsync(x =>
                    x.TokenHash == hash &&
                    x.WorkLocationId == locationId &&
                    x.Purpose == purpose &&
                    !x.IsRevoked &&
                    x.ExpiresAtUtc > now);
        }

        // ========================================
        // 7. KIEM TRA KHOANG CACH GPS
        // ========================================

        private static string? ValidateLocation(
            AttendanceActionRequest request,
            WorkLocation location)
        {
            if (request.Latitude < -90 ||
                request.Latitude > 90 ||
                request.Longitude < -180 ||
                request.Longitude > 180)
            {
                return "Tọa độ GPS không hợp lệ.";
            }

            if (request.AccuracyMeters < 0 ||
                request.AccuracyMeters > 500)
            {
                return "Độ chính xác GPS không đạt yêu cầu.";
            }

            var distance = CalculateDistanceMeters(
                (double)request.Latitude,
                (double)request.Longitude,
                (double)location.Latitude,
                (double)location.Longitude);

            if (distance > location.AllowedRadiusMeters)
            {
                return "Bạn đang ở ngoài phạm vi chấm công.";
            }

            return null;
        }

        private static double CalculateDistanceMeters(
            double lat1,
            double lon1,
            double lat2,
            double lon2)
        {
            const double earthRadius = 6371000;

            var dLat = ToRadians(lat2 - lat1);
            var dLon = ToRadians(lon2 - lon1);

            var a =
                Math.Pow(Math.Sin(dLat / 2), 2) +
                Math.Cos(ToRadians(lat1)) *
                Math.Cos(ToRadians(lat2)) *
                Math.Pow(Math.Sin(dLon / 2), 2);

            var c = 2 * Math.Atan2(
                Math.Sqrt(a),
                Math.Sqrt(1 - a));

            return earthRadius * c;
        }

        private static double ToRadians(double degrees)
        {
            return degrees * Math.PI / 180.0;
        }

        // ========================================
        // 8. ADMIN XEM LICH SU CHAM CONG TOAN BO
        // ========================================

        [HttpGet("all")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAllAttendance(
            [FromQuery] int? employeeId,
            [FromQuery] DateOnly? workDate,
            [FromQuery] string? status)
        {
            var query = _db.Set<AttendanceRecord>()
                .AsNoTracking()
                .AsQueryable();

            if (employeeId.HasValue)
            {
                query = query.Where(x => x.ShiftAssignment.EmployeeId == employeeId.Value);
            }

            if (workDate.HasValue)
            {
                query = query.Where(x => x.ShiftAssignment.WorkDate == workDate.Value);
            }

            if (!string.IsNullOrWhiteSpace(status))
            {
                query = query.Where(x => x.CheckInStatus == status);
            }

            var records = await query
                .OrderByDescending(x => x.ShiftAssignment.WorkDate)
                .ThenByDescending(x => x.CheckInUtc)
                .Select(x => new
                {
                    x.Id,
                    x.ShiftAssignmentId,
                    x.ShiftAssignment.EmployeeId,
                    EmployeeCode = x.ShiftAssignment.Employee.EmployeeCode,
                    EmployeeName = x.ShiftAssignment.Employee.ApplicationUser.FullName,
                    DepartmentName = x.ShiftAssignment.Employee.Department != null
                        ? x.ShiftAssignment.Employee.Department.Name : null,
                    WorkDate = x.ShiftAssignment.WorkDate,
                    ShiftName = x.ShiftAssignment.Shift.Name,
                    LocationName = x.ShiftAssignment.WorkLocation.Name,
                    x.CheckInUtc,
                    x.CheckOutUtc,
                    x.CheckInLatitude,
                    x.CheckInLongitude,
                    x.CheckOutLatitude,
                    x.CheckOutLongitude,
                    x.CheckInStatus
                })
                .ToListAsync();

            return Ok(new
            {
                total = records.Count,
                records
            });
        }

    }

    // ========================================
    // DTO TAO QR
    // ========================================

    public class CreateAttendanceQrRequest
    {
        [Range(1, int.MaxValue)]
        public int WorkLocationId { get; set; }

        [Required]
        public string Purpose { get; set; } = string.Empty;
    }

    // ========================================
    // DTO CHECK-IN / CHECK-OUT
    // ========================================

    public class AttendanceActionRequest
    {
        [Range(1, int.MaxValue)]
        public int ShiftAssignmentId { get; set; }

        [Range(typeof(decimal), "-90", "90")]
        public decimal Latitude { get; set; }

        [Range(typeof(decimal), "-180", "180")]
        public decimal Longitude { get; set; }

        [Range(typeof(decimal), "0", "100")]
        public decimal AccuracyMeters { get; set; }

        [Required]
        public string QrPayload { get; set; } = string.Empty;
    }
}
