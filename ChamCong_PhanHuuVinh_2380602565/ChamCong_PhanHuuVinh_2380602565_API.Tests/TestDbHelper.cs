using Microsoft.EntityFrameworkCore;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests
{
    public static class TestDbHelper
    {
        public static ApplicationDbContext CreateInMemoryDbContext()
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(databaseName: "SmartCheck_Test_" + Guid.NewGuid().ToString("N"))
                .Options;

            return new ApplicationDbContext(options);
        }

        public static async Task<(ApplicationUser adminUser, ApplicationUser empUser, Employee employee, Department dept, Shift shift, WorkLocation loc)> SeedBasicDataAsync(ApplicationDbContext db)
        {
            var adminUser = new ApplicationUser
            {
                Id = "admin-test-id",
                UserName = "admin_test",
                Email = "admin_test@smartcheck.vn",
                FullName = "Quản trị viên Test",
                EmailConfirmed = true,
                IsActive = true
            };

            var empUser = new ApplicationUser
            {
                Id = "emp-test-id",
                UserName = "employee_test",
                Email = "emp_test@smartcheck.vn",
                FullName = "Nhân viên Test",
                EmailConfirmed = true,
                IsActive = true
            };

            var dept = new Department
            {
                Id = 1,
                Name = "Phòng Kỹ Thuật",
                Description = "Phòng phát triển phần mềm",
                IsActive = true
            };

            var employee = new Employee
            {
                Id = 1,
                EmployeeCode = "NVTEST001",
                ApplicationUserId = empUser.Id,
                ApplicationUser = empUser,
                DepartmentId = dept.Id,
                Department = dept,
                IsActive = true
            };

            var shift = new Shift
            {
                Id = 1,
                Name = "Ca Hành Chính",
                StartTime = new TimeSpan(8, 0, 0),
                EndTime = new TimeSpan(17, 30, 0),
                GraceMinutes = 15,
                IsActive = true
            };

            var loc = new WorkLocation
            {
                Id = 1,
                Name = "Trụ Sở Chính",
                Address = "Tòa nhà Công nghệ, TP.HCM",
                Latitude = 10.7769m,
                Longitude = 106.7009m,
                AllowedRadiusMeters = 200, // 200m
                IsActive = true
            };

            db.Users.AddRange(adminUser, empUser);
            db.Set<Department>().Add(dept);
            db.Set<Employee>().Add(employee);
            db.Set<Shift>().Add(shift);
            db.Set<WorkLocation>().Add(loc);

            await db.SaveChangesAsync();

            return (adminUser, empUser, employee, dept, shift, loc);
        }
    }
}
