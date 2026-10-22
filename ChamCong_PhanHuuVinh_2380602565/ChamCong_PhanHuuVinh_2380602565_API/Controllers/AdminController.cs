
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Controllers
{
    [ApiController]
    [Route("api/admin")]
    [Authorize(Roles = "Admin")]
    public class AdminController : ControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly ILogger<AdminController> _logger;

        public AdminController(
            ApplicationDbContext db,
            ILogger<AdminController> logger)
        {
            _db = db;
            _logger = logger;
        }

        // ========================================
        // 1. DASHBOARD ADMIN
        // ========================================

        [HttpGet("dashboard")]
        public async Task<IActionResult> GetDashboard()
        {
            var employees = _db.Set<Employee>();

            var totalEmployees =
                await employees.CountAsync();

            var activeEmployees =
                await employees.CountAsync(e =>
                    e.IsActive &&
                    e.ApplicationUser.IsActive);

            var pendingEmployees =
                await employees.CountAsync(e =>
                    e.ApplicationUser.EmailConfirmed &&
                    (!e.IsActive ||
                     !e.ApplicationUser.IsActive));

            var totalDepartments =
                await _db.Set<Department>().CountAsync();

            var totalShifts =
                await _db.Set<Shift>().CountAsync();

            var totalLocations =
                await _db.Set<WorkLocation>().CountAsync();

            return Ok(new
            {
                totalEmployees,
                activeEmployees,
                pendingEmployees,
                totalDepartments,
                totalShifts,
                totalLocations
            });
        }

        // ========================================
        // 2.1. DANH SACH TOAN BO NHAN VIEN
        // ========================================

        [HttpGet("employees")]
        public async Task<IActionResult> GetAllEmployees(
            [FromQuery] int? departmentId,
            [FromQuery] bool? isActive)
        {
            var query = _db.Set<Employee>()
                .AsNoTracking()
                .Include(e => e.ApplicationUser)
                .Include(e => e.Department)
                .AsQueryable();

            if (departmentId.HasValue)
            {
                query = query.Where(e => e.DepartmentId == departmentId.Value);
            }

            if (isActive.HasValue)
            {
                query = isActive.Value
                    ? query.Where(e => e.IsActive && e.ApplicationUser.IsActive)
                    : query.Where(e => !e.IsActive || !e.ApplicationUser.IsActive);
            }

            var employees = await query
                .OrderBy(e => e.Id)
                .Select(e => new
                {
                    employeeId = e.Id,
                    employeeCode = e.EmployeeCode,
                    userName = e.ApplicationUser.UserName,
                    fullName = e.ApplicationUser.FullName,
                    email = e.ApplicationUser.Email,
                    emailConfirmed = e.ApplicationUser.EmailConfirmed,
                    isActive = e.IsActive,
                    userActive = e.ApplicationUser.IsActive,
                    departmentId = e.DepartmentId,
                    departmentName = e.Department != null ? e.Department.Name : null,
                    hireDate = e.HireDate
                })
                .ToListAsync();

            return Ok(new
            {
                total = employees.Count,
                employees
            });
        }

        // ========================================
        // 2.2. CHI TIET NHAN VIEN
        // ========================================

        [HttpGet("employees/{id:int}")]
        public async Task<IActionResult> GetEmployeeById(int id)
        {
            var e = await _db.Set<Employee>()
                .AsNoTracking()
                .Include(e => e.ApplicationUser)
                .Include(e => e.Department)
                .Where(x => x.Id == id)
                .Select(e => new
                {
                    employeeId = e.Id,
                    employeeCode = e.EmployeeCode,
                    userName = e.ApplicationUser.UserName,
                    fullName = e.ApplicationUser.FullName,
                    email = e.ApplicationUser.Email,
                    emailConfirmed = e.ApplicationUser.EmailConfirmed,
                    isActive = e.IsActive,
                    userActive = e.ApplicationUser.IsActive,
                    departmentId = e.DepartmentId,
                    departmentName = e.Department != null ? e.Department.Name : null,
                    hireDate = e.HireDate
                })
                .FirstOrDefaultAsync();

            if (e == null)
            {
                return NotFound(new { message = "Không tìm thấy nhân viên." });
            }

            return Ok(e);
        }

        // ========================================
        // 2.3. CAP NHAT THONG TIN NHAN VIEN
        // ========================================

        [HttpPut("employees/{id:int}")]
        public async Task<IActionResult> UpdateEmployee(
            int id,
            [FromBody] UpdateEmployeeRequest request)
        {
            var employee = await _db.Set<Employee>()
                .Include(e => e.ApplicationUser)
                .FirstOrDefaultAsync(e => e.Id == id);

            if (employee == null)
            {
                return NotFound(new { message = "Không tìm thấy nhân viên." });
            }

            if (request.DepartmentId.HasValue)
            {
                var deptExists = await _db.Set<Department>().AnyAsync(d => d.Id == request.DepartmentId.Value);
                if (!deptExists)
                {
                    return BadRequest(new { message = "Phòng ban không tồn tại." });
                }
                employee.DepartmentId = request.DepartmentId;
            }
            else if (request.ClearDepartment == true)
            {
                employee.DepartmentId = null;
            }

            if (request.HireDate.HasValue)
            {
                employee.HireDate = request.HireDate.Value;
            }

            if (!string.IsNullOrWhiteSpace(request.FullName))
            {
                employee.ApplicationUser.FullName = request.FullName.Trim();
            }

            await _db.SaveChangesAsync();

            return Ok(new
            {
                message = "Cập nhật nhân viên thành công.",
                employeeId = employee.Id
            });
        }

        // ========================================
        // 2. XEM NHAN VIEN CHO DUYET
        // ========================================

        [HttpGet("employees/pending")]
        public async Task<IActionResult> GetPendingEmployees()
        {
            var employees = await _db.Set<Employee>()
                .AsNoTracking()
                .Where(e =>
                    e.ApplicationUser.EmailConfirmed &&
                    (!e.IsActive ||
                     !e.ApplicationUser.IsActive))
                .OrderBy(e => e.Id)
                .Select(e => new
                {
                    employeeId = e.Id,
                    employeeCode = e.EmployeeCode,
                    userName = e.ApplicationUser.UserName,
                    fullName = e.ApplicationUser.FullName,
                    email = e.ApplicationUser.Email,
                    emailConfirmed =
                        e.ApplicationUser.EmailConfirmed,
                    isActive = e.IsActive,
                    departmentId = e.DepartmentId
                })
                .ToListAsync();

            return Ok(new
            {
                total = employees.Count,
                employees
            });
        }

        // ========================================
        // 3. KICH HOAT NHAN VIEN
        // ========================================

        [HttpPut("employees/{id:int}/activate")]
        public async Task<IActionResult> ActivateEmployee(int id)
        {
            var employee = await _db.Set<Employee>()
                .Include(e => e.ApplicationUser)
                .FirstOrDefaultAsync(e => e.Id == id);

            if (employee == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy nhân viên."
                });
            }

            var user = employee.ApplicationUser;

            // Bat buoc xac minh email truoc
            if (!user.EmailConfirmed)
            {
                return BadRequest(new
                {
                    message =
                        "Nhân viên chưa xác minh email."
                });
            }

            if (employee.IsActive && user.IsActive)
            {
                return Ok(new
                {
                    message =
                        "Nhân viên đã được kích hoạt trước đó."
                });
            }

            // Kich hoat ho so nhan vien
            employee.IsActive = true;

            // Kich hoat tai khoan dang nhap
            user.IsActive = true;

            await _db.SaveChangesAsync();

            _logger.LogInformation(
                "Admin {Admin} kich hoat nhan vien {EmployeeId}",
                User.Identity?.Name,
                employee.Id);

            return Ok(new
            {
                message = "Kích hoạt nhân viên thành công.",
                employeeId = employee.Id,
                userName = user.UserName,
                isActive = true
            });
        }

        // ========================================
        // 4. VO HIEU HOA NHAN VIEN
        // ========================================

        [HttpPut("employees/{id:int}/deactivate")]
        public async Task<IActionResult> DeactivateEmployee(int id)
        {
            var employee = await _db.Set<Employee>()
                .Include(e => e.ApplicationUser)
                .FirstOrDefaultAsync(e => e.Id == id);

            if (employee == null)
            {
                return NotFound(new
                {
                    message = "Không tìm thấy nhân viên."
                });
            }

            var user = employee.ApplicationUser;

            if (!employee.IsActive && !user.IsActive)
            {
                return Ok(new
                {
                    message =
                        "Nhân viên đã bị vô hiệu hóa trước đó."
                });
            }

            employee.IsActive = false;
            user.IsActive = false;

            await _db.SaveChangesAsync();

            _logger.LogInformation(
                "Admin {Admin} vo hieu hoa nhan vien {EmployeeId}",
                User.Identity?.Name,
                employee.Id);

            return Ok(new
            {
                message = "Vô hiệu hóa nhân viên thành công.",
                employeeId = employee.Id,
                userName = user.UserName,
                isActive = false
            });
        }
    }

    public class UpdateEmployeeRequest
    {
        public int? DepartmentId { get; set; }
        public bool? ClearDepartment { get; set; }
        public DateTime? HireDate { get; set; }
        public string? FullName { get; set; }
    }
}
