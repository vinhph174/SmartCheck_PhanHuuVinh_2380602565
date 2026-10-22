using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Xunit;
using ChamCong_PhanHuuVinh_2380602565_API.Controllers;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests
{
    public class AttendanceQrGpsTests
    {
        private static AttendanceController CreateControllerWithUser(ApplicationDbContext db, string userId)
        {
            var controller = new AttendanceController(db);
            var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId),
                new Claim(ClaimTypes.Role, "Employee")
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = user }
            };

            return controller;
        }

        [Fact]
        public async Task CheckIn_WithExpiredQr_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Create shift assignment
            var assignment = new ShiftAssignment
            {
                Id = 10,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // Create EXPIRED QR session (expired 10 minutes ago)
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

            var expiredQr = new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow.AddMinutes(-12),
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(-10),
                IsRevoked = false
            };
            db.Set<QrSession>().Add(expiredQr);
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);

            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 10
            };

            var result = await controller.CheckIn(req);
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Contains("hết hạn", badRequest.Value?.ToString() ?? "");
        }

        [Fact]
        public async Task CheckIn_WithGpsOutOfRange_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Location is at 10.7769, 106.7009 (TP.HCM) with allowed radius = 200m
            var assignment = new ShiftAssignment
            {
                Id = 11,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // Create valid QR session
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

            var qr = new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5),
                IsRevoked = false
            };
            db.Set<QrSession>().Add(qr);
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);

            // Far away coordinate: Ha Noi (21.0285, 105.8542) ~ 1100 km away!
            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = 21.0285m,
                Longitude = 105.8542m,
                AccuracyMeters = 10
            };

            var result = await controller.CheckIn(req);
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Contains("ngoài phạm vi", badRequest.Value?.ToString() ?? "");
        }

        [Fact]
        public async Task CheckIn_ValidQrAndGps_SucceedsAndUpdatesShiftStatus()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var assignment = new ShiftAssignment
            {
                Id = 12,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // Valid QR session
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

            var qr = new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5),
                IsRevoked = false
            };
            db.Set<QrSession>().Add(qr);
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);

            // Coordinates right on-site (within 200m)
            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 5
            };

            var result = await controller.CheckIn(req);
            Assert.IsType<OkObjectResult>(result);

            // Verification in DB
            var updatedAssignment = await db.Set<ShiftAssignment>().FindAsync(assignment.Id);
            Assert.NotNull(updatedAssignment);
            Assert.Equal("InProgress", updatedAssignment.Status);

            var record = db.Set<AttendanceRecord>().FirstOrDefault(r => r.ShiftAssignmentId == assignment.Id);
            Assert.NotNull(record);
            Assert.NotNull(record.CheckInUtc);
        }

        [Fact]
        public async Task CheckIn_DuplicateCheckIn_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Assignment already InProgress
            var assignment = new ShiftAssignment
            {
                Id = 13,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "InProgress"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // AttendanceRecord already has CheckInUtc
            var existingRecord = new AttendanceRecord
            {
                ShiftAssignmentId = assignment.Id,
                CheckInUtc = DateTimeOffset.UtcNow.AddHours(-1),
                CheckInStatus = "OnTime"
            };
            db.Set<AttendanceRecord>().Add(existingRecord);

            // QR
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
            db.Set<QrSession>().Add(new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5)
            });
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);

            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 10
            };

            var result = await controller.CheckIn(req);
            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task CheckOut_WithoutPriorCheckIn_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Assignment is Scheduled (not InProgress)
            var assignment = new ShiftAssignment
            {
                Id = 14,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
            db.Set<QrSession>().Add(new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckOut",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5)
            });
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);

            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 10
            };

            var result = await controller.CheckOut(req);
            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task FullAttendanceLifecycle_AdminAssignsShift_CreatesQr_EmployeeChecksInAndOut_VerifiedInDb()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // 1. Phân ca cho nhân viên
            var assignment = new ShiftAssignment
            {
                Id = 15,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);
            await db.SaveChangesAsync();

            // 2. Tạo QR Check-in
            var inToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var inHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(inToken)));
            var inQrId = Guid.NewGuid();
            db.Set<QrSession>().Add(new QrSession
            {
                Id = inQrId,
                WorkLocationId = loc.Id,
                TokenHash = inHash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5)
            });
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);

            // 3. Nhân viên Check-in tại điểm làm việc
            var inReq = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + inToken,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 8
            };
            var inRes = await controller.CheckIn(inReq);
            Assert.IsType<OkObjectResult>(inRes);

            // Kiểm tra DB sau Check-in
            var checkInAssignment = await db.Set<ShiftAssignment>().FindAsync(assignment.Id);
            Assert.NotNull(checkInAssignment);
            Assert.Equal("InProgress", checkInAssignment.Status);

            var record = db.Set<AttendanceRecord>().FirstOrDefault(r => r.ShiftAssignmentId == assignment.Id);
            Assert.NotNull(record);
            Assert.NotNull(record.CheckInUtc);
            Assert.Equal(inQrId, record.CheckInQrSessionId);
            Assert.Equal(loc.Latitude, record.CheckInLatitude);
            Assert.Equal(loc.Longitude, record.CheckInLongitude);

            // 4. Tạo QR Check-out
            var outToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var outHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(outToken)));
            var outQrId = Guid.NewGuid();
            db.Set<QrSession>().Add(new QrSession
            {
                Id = outQrId,
                WorkLocationId = loc.Id,
                TokenHash = outHash,
                Purpose = "CheckOut",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5)
            });
            await db.SaveChangesAsync();

            // 5. Nhân viên Check-out tại điểm làm việc
            var outReq = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + outToken,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 8
            };
            var outRes = await controller.CheckOut(outReq);
            Assert.IsType<OkObjectResult>(outRes);

            // Kiểm tra DB sau Check-out
            var checkOutAssignment = await db.Set<ShiftAssignment>().FindAsync(assignment.Id);
            Assert.NotNull(checkOutAssignment);
            Assert.Equal("Completed", checkOutAssignment.Status);

            var finalRecord = db.Set<AttendanceRecord>().FirstOrDefault(r => r.ShiftAssignmentId == assignment.Id);
            Assert.NotNull(finalRecord);
            Assert.NotNull(finalRecord.CheckOutUtc);
            Assert.Equal(outQrId, finalRecord.CheckOutQrSessionId);
            Assert.True(finalRecord.CheckOutUtc >= finalRecord.CheckInUtc);
        }

        [Fact]
        public async Task CheckIn_WithWrongQrPurpose_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var assignment = new ShiftAssignment
            {
                Id = 41,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // Tạo QR với mục đích CheckOut thay vì CheckIn
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
            db.Set<QrSession>().Add(new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckOut", // Sai mục đích
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5),
                IsRevoked = false
            });
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);
            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 10
            };

            var result = await controller.CheckIn(req);
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Contains("không hợp lệ", badRequest.Value?.ToString() ?? "");
        }

        [Fact]
        public async Task CheckIn_WithQrFromDifferentLocation_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var loc2 = new WorkLocation
            {
                Id = 2,
                Name = "Chi nhánh 2",
                Address = "Địa chỉ khác",
                Latitude = 10.8000m,
                Longitude = 106.8000m,
                AllowedRadiusMeters = 150,
                IsActive = true
            };
            db.Set<WorkLocation>().Add(loc2);

            var assignment = new ShiftAssignment
            {
                Id = 42,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id, // Ca tại Trụ Sở Chính (loc 1)
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // Tạo QR cho Chi nhánh 2 (loc 2)
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
            db.Set<QrSession>().Add(new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc2.Id, // Tạo cho địa điểm khác
                TokenHash = hash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5),
                IsRevoked = false
            });
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);
            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 10
            };

            var result = await controller.CheckIn(req);
            var badRequest = Assert.IsType<BadRequestObjectResult>(result);
            Assert.Contains("không hợp lệ", badRequest.Value?.ToString() ?? "");
        }

        [Fact]
        public async Task CheckIn_WhenShiftIsNotToday_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Ca làm việc được lên lịch cho ngày mai
            var tomorrow = DateOnly.FromDateTime(DateTime.Today.AddDays(1));
            var assignment = new ShiftAssignment
            {
                Id = 43,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = tomorrow,
                Status = "Scheduled"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
            var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
            db.Set<QrSession>().Add(new QrSession
            {
                Id = Guid.NewGuid(),
                WorkLocationId = loc.Id,
                TokenHash = hash,
                Purpose = "CheckIn",
                CreatedAtUtc = DateTimeOffset.UtcNow,
                ExpiresAtUtc = DateTimeOffset.UtcNow.AddMinutes(5),
                IsRevoked = false
            });
            await db.SaveChangesAsync();

            var controller = CreateControllerWithUser(db, empUser.Id);
            var req = new AttendanceActionRequest
            {
                ShiftAssignmentId = assignment.Id,
                QrPayload = "SC1:" + token,
                Latitude = loc.Latitude,
                Longitude = loc.Longitude,
                AccuracyMeters = 10
            };

            var result = await controller.CheckIn(req);
            var conflict = Assert.IsType<ConflictObjectResult>(result);
            Assert.Contains("Hôm nay không phải ngày", conflict.Value?.ToString() ?? "");
        }

        [Fact]
        public async Task LocationShare_ValidCoordinates_ReturnsOkAndSavesToDb()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, _, _) = await TestDbHelper.SeedBasicDataAsync(db);

            var controller = new LocationSharesController(db);
            var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, empUser.Id),
                new Claim(ClaimTypes.Role, "Employee")
            }, "TestAuth"));
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = user }
            };

            var req = new LocationShareRequest
            {
                Latitude = 10.7769m,
                Longitude = 106.7009m,
                AccuracyMeters = 15.5,
                Note = "Khảo sát thực địa quận 1"
            };

            var result = await controller.ShareLocation(req);
            Assert.IsType<OkObjectResult>(result);

            var record = db.Set<LocationShare>().FirstOrDefault(l => l.EmployeeId == employee.Id);
            Assert.NotNull(record);
            Assert.Equal(10.7769m, record.Latitude);
            Assert.Equal(106.7009m, record.Longitude);
            Assert.Equal(15.5, record.AccuracyMeters);
            Assert.Equal("Khảo sát thực địa quận 1", record.Note);
        }

        [Theory]
        [InlineData(95.0, 106.0, 10.0)]     // Latitude > 90
        [InlineData(-95.0, 106.0, 10.0)]    // Latitude < -90
        [InlineData(10.0, 190.0, 10.0)]     // Longitude > 180
        [InlineData(10.0, 106.0, -5.0)]      // Accuracy < 0
        [InlineData(10.0, 106.0, 15000.0)]   // Accuracy > 10000m
        public async Task LocationShare_InvalidCoordinatesOrAccuracy_ReturnsBadRequest(double lat, double lon, double acc)
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, _, _, _, _) = await TestDbHelper.SeedBasicDataAsync(db);

            var controller = new LocationSharesController(db);
            var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, empUser.Id),
                new Claim(ClaimTypes.Role, "Employee")
            }, "TestAuth"));
            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = user }
            };

            var req = new LocationShareRequest
            {
                Latitude = (decimal)lat,
                Longitude = (decimal)lon,
                AccuracyMeters = acc,
                Note = "Dữ liệu lỗi"
            };

            var result = await controller.ShareLocation(req);
            Assert.IsType<BadRequestObjectResult>(result);
        }
    }
}
