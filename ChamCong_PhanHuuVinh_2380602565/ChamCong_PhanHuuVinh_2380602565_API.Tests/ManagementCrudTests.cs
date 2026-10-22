using Microsoft.AspNetCore.Mvc;
using Xunit;
using ChamCong_PhanHuuVinh_2380602565_API.Controllers;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests
{
    public class ManagementCrudTests
    {
        [Fact]
        public async Task CreateDepartment_WithValidData_ReturnsCreated()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new DepartmentCrudRequest
            {
                Name = "Phòng Tài Chính",
                Description = "Quản lý ngân sách",
                IsActive = true
            };

            var actionResult = await controller.CreateDepartment(req);
            Assert.IsType<CreatedResult>(actionResult);

            var inDb = db.Set<Department>().FirstOrDefault(d => d.Name == "Phòng Tài Chính");
            Assert.NotNull(inDb);
            Assert.True(inDb.IsActive);
        }

        [Fact]
        public async Task CreateDepartment_WithEmptyName_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new DepartmentCrudRequest
            {
                Name = "   ",
                Description = "Mô tả",
                IsActive = true
            };

            var actionResult = await controller.CreateDepartment(req);
            Assert.IsType<BadRequestObjectResult>(actionResult);
        }

        [Fact]
        public async Task CreateDepartment_WithDuplicateName_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            db.Set<Department>().Add(new Department
            {
                Name = "Phòng Kỹ Thuật",
                IsActive = true
            });
            await db.SaveChangesAsync();
            var controller = new ManagementCrudController(db);

            var result = await controller.CreateDepartment(
                new DepartmentCrudRequest
                {
                    Name = "Phòng Kỹ Thuật",
                    IsActive = true
                });

            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task CreateShift_WithValidData_ReturnsCreated()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new ShiftCrudRequest
            {
                Name = "Ca Tối",
                StartTime = new TimeSpan(18, 0, 0),
                EndTime = new TimeSpan(22, 0, 0),
                GraceMinutes = 10,
                IsActive = true
            };

            var actionResult = await controller.CreateShift(req);
            Assert.IsType<CreatedResult>(actionResult);

            var inDb = db.Set<Shift>().FirstOrDefault(s => s.Name == "Ca Tối");
            Assert.NotNull(inDb);
            Assert.Equal(10, inDb.GraceMinutes);
        }

        [Fact]
        public async Task CreateShift_WithEqualStartAndEndTime_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new ShiftCrudRequest
            {
                Name = "Ca Lỗi",
                StartTime = new TimeSpan(8, 0, 0),
                EndTime = new TimeSpan(8, 0, 0),
                GraceMinutes = 15,
                IsActive = true
            };

            var actionResult = await controller.CreateShift(req);
            Assert.IsType<BadRequestObjectResult>(actionResult);
        }

        [Fact]
        public async Task CreateShift_WithNegativeGraceMinutes_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new ShiftCrudRequest
            {
                Name = "Ca Âm Grace",
                StartTime = new TimeSpan(8, 0, 0),
                EndTime = new TimeSpan(17, 0, 0),
                GraceMinutes = -5,
                IsActive = true
            };

            var actionResult = await controller.CreateShift(req);
            Assert.IsType<BadRequestObjectResult>(actionResult);
        }

        [Fact]
        public async Task CreateShift_WithDuplicateName_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            db.Set<Shift>().Add(new Shift
            {
                Name = "Ca Sáng",
                StartTime = new TimeSpan(8, 0, 0),
                EndTime = new TimeSpan(17, 0, 0),
                GraceMinutes = 10,
                IsActive = true
            });
            await db.SaveChangesAsync();
            var controller = new ManagementCrudController(db);

            var result = await controller.CreateShift(new ShiftCrudRequest
            {
                Name = "Ca Sáng",
                StartTime = new TimeSpan(9, 0, 0),
                EndTime = new TimeSpan(18, 0, 0),
                GraceMinutes = 5,
                IsActive = true
            });

            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task CreateLocation_WithValidGpsCoordinates_ReturnsCreated()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new WorkLocationCrudRequest
            {
                Name = "Chi nhánh Quận 1",
                Address = "Số 1 Lê Duẩn, Q1, TP.HCM",
                Latitude = 10.7801m,
                Longitude = 106.7002m,
                AllowedRadiusMeters = 300,
                IsActive = true
            };

            var actionResult = await controller.CreateLocation(req);
            Assert.IsType<CreatedResult>(actionResult);

            var inDb = db.Set<WorkLocation>().FirstOrDefault(w => w.Name == "Chi nhánh Quận 1");
            Assert.NotNull(inDb);
            Assert.Equal(300, inDb.AllowedRadiusMeters);
        }

        [Theory]
        [InlineData(95.0, 106.0, 100)]    // Latitude > 90
        [InlineData(-95.0, 106.0, 100)]   // Latitude < -90
        [InlineData(10.0, 190.0, 100)]    // Longitude > 180
        [InlineData(10.0, 106.0, 0)]      // Radius <= 0
        [InlineData(10.0, 106.0, 6000)]   // Radius > 5000m
        public async Task CreateLocation_WithInvalidGps_ReturnsBadRequest(double lat, double lon, int radius)
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var controller = new ManagementCrudController(db);

            var req = new WorkLocationCrudRequest
            {
                Name = "Vị trí không hợp lệ",
                Address = "Địa chỉ test",
                Latitude = (decimal)lat,
                Longitude = (decimal)lon,
                AllowedRadiusMeters = radius,
                IsActive = true
            };

            var actionResult = await controller.CreateLocation(req);
            Assert.IsType<BadRequestObjectResult>(actionResult);
        }

        [Fact]
        public async Task CreateLocation_WithDuplicateName_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            db.Set<WorkLocation>().Add(new WorkLocation
            {
                Name = "Văn phòng chính",
                Address = "TP.HCM",
                Latitude = 10.77m,
                Longitude = 106.70m,
                AllowedRadiusMeters = 200,
                IsActive = true
            });
            await db.SaveChangesAsync();
            var controller = new ManagementCrudController(db);

            var result = await controller.CreateLocation(new WorkLocationCrudRequest
            {
                Name = "Văn phòng chính",
                Address = "Địa chỉ khác",
                Latitude = 10.78m,
                Longitude = 106.71m,
                AllowedRadiusMeters = 150,
                IsActive = true
            });

            Assert.IsType<ConflictObjectResult>(result);
        }
    }
}
