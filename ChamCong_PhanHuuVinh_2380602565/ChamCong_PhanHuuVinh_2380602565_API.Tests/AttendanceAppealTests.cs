using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Xunit;
using ChamCong_PhanHuuVinh_2380602565_API.Controllers;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests
{
    public class AttendanceAppealTests
    {
        private static AttendanceAppealsController CreateController(ApplicationDbContext db, string userId, string role = "Employee")
        {
            var controller = new AttendanceAppealsController(db);
            var user = new ClaimsPrincipal(new ClaimsIdentity(new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId),
                new Claim(ClaimTypes.Role, role)
            }, "TestAuth"));

            controller.ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext { User = user }
            };

            return controller;
        }

        [Fact]
        public async Task CreateAppeal_ForOwnShift_Succeeds()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var assignment = new ShiftAssignment
            {
                Id = 20,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "InProgress"
            };
            db.Set<ShiftAssignment>().Add(assignment);
            await db.SaveChangesAsync();

            var controller = CreateController(db, empUser.Id, "Employee");

            var req = new CreateAppealRequest
            {
                ShiftAssignmentId = assignment.Id,
                Reason = "Quên chấm công ra do mất kết nối mạng 4G"
            };

            var result = await controller.CreateAppeal(req);
            Assert.IsType<OkObjectResult>(result);

            var appeal = db.Set<AttendanceAppeal>().FirstOrDefault(a => a.ShiftAssignmentId == assignment.Id);
            Assert.NotNull(appeal);
            Assert.Equal("Pending", appeal.Status);
            Assert.Equal(employee.Id, appeal.EmployeeId);
        }

        [Fact]
        public async Task CreateAppeal_ForAnotherEmployeeShift_ReturnsNotFound()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, _, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Create another employee (Id = 99)
            var otherEmpUser = new ApplicationUser
            {
                Id = "other-emp-guid",
                UserName = "other_emp",
                Email = "other@test.vn",
                EmailConfirmed = true,
                IsActive = true
            };
            var otherEmployee = new Employee
            {
                Id = 99,
                EmployeeCode = "NVOTHER99",
                ApplicationUserId = otherEmpUser.Id,
                DepartmentId = 1,
                IsActive = true
            };
            db.Users.Add(otherEmpUser);
            db.Set<Employee>().Add(otherEmployee);

            // Shift belongs to otherEmployee (Id = 99)
            var otherAssignment = new ShiftAssignment
            {
                Id = 21,
                EmployeeId = otherEmployee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            db.Set<ShiftAssignment>().Add(otherAssignment);
            await db.SaveChangesAsync();

            // Original employee tries to appeal other employee's shift
            var controller = CreateController(db, empUser.Id, "Employee");

            var req = new CreateAppealRequest
            {
                ShiftAssignmentId = otherAssignment.Id,
                Reason = "Cố tình giải trình hộ người khác"
            };

            var result = await controller.CreateAppeal(req);
            Assert.IsType<NotFoundObjectResult>(result);
        }

        [Fact]
        public async Task CreateAppeal_DuplicatePendingAppeal_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var assignment = new ShiftAssignment
            {
                Id = 22,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            // Already has pending appeal
            var existingAppeal = new AttendanceAppeal
            {
                EmployeeId = employee.Id,
                ShiftAssignmentId = assignment.Id,
                Reason = "Lý do 1",
                Status = "Pending"
            };
            db.Set<AttendanceAppeal>().Add(existingAppeal);
            await db.SaveChangesAsync();

            var controller = CreateController(db, empUser.Id, "Employee");

            var req = new CreateAppealRequest
            {
                ShiftAssignmentId = assignment.Id,
                Reason = "Lý do 2 gửi lặp"
            };

            var result = await controller.CreateAppeal(req);
            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task CreateAppeal_AfterApproved_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);
            var assignment = new ShiftAssignment
            {
                Id = 220,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            db.Set<ShiftAssignment>().Add(assignment);
            db.Set<AttendanceAppeal>().Add(new AttendanceAppeal
            {
                EmployeeId = employee.Id,
                ShiftAssignmentId = assignment.Id,
                Reason = "Yêu cầu đã được duyệt",
                Status = "Approved"
            });
            await db.SaveChangesAsync();

            var result = await CreateController(db, empUser.Id)
                .CreateAppeal(new CreateAppealRequest
                {
                    ShiftAssignmentId = assignment.Id,
                    Reason = "Không được gửi lại khi đã duyệt"
                });

            Assert.IsType<ConflictObjectResult>(result);
        }

        [Fact]
        public async Task CreateAppeal_AfterRejected_CreatesNewPendingAppeal()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);
            var assignment = new ShiftAssignment
            {
                Id = 221,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            db.Set<ShiftAssignment>().Add(assignment);
            db.Set<AttendanceAppeal>().Add(new AttendanceAppeal
            {
                EmployeeId = employee.Id,
                ShiftAssignmentId = assignment.Id,
                Reason = "Yêu cầu cũ bị từ chối",
                Status = "Rejected"
            });
            await db.SaveChangesAsync();

            var result = await CreateController(db, empUser.Id)
                .CreateAppeal(new CreateAppealRequest
                {
                    ShiftAssignmentId = assignment.Id,
                    Reason = "Bổ sung thông tin để gửi lại"
                });

            Assert.IsType<OkObjectResult>(result);
            Assert.Equal(
                2,
                db.Set<AttendanceAppeal>().Count(a =>
                    a.ShiftAssignmentId == assignment.Id));
            Assert.Single(db.Set<AttendanceAppeal>().Where(a =>
                a.ShiftAssignmentId == assignment.Id && a.Status == "Pending"));
        }

        [Fact]
        public async Task Admin_ReviewAppeal_UpdatesStatusAndReviewNote()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (adminUser, _, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var assignment = new ShiftAssignment
            {
                Id = 23,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            db.Set<ShiftAssignment>().Add(assignment);

            var appeal = new AttendanceAppeal
            {
                Id = 50,
                EmployeeId = employee.Id,
                ShiftAssignmentId = assignment.Id,
                Reason = "Lý do hợp lệ",
                Status = "Pending"
            };
            db.Set<AttendanceAppeal>().Add(appeal);
            await db.SaveChangesAsync();

            var controller = CreateController(db, adminUser.Id, "Admin");

            var reviewReq = new ReviewAppealRequest
            {
                Status = "Approved",
                ReviewNote = "Đã xác nhận sự cố mạng, duyệt chấm công bổ sung"
            };

            var result = await controller.ReviewAppeal(appeal.Id, reviewReq);
            Assert.IsType<OkObjectResult>(result);

            var updated = await db.Set<AttendanceAppeal>().FindAsync(appeal.Id);
            Assert.NotNull(updated);
            Assert.Equal("Approved", updated.Status);
            Assert.Equal(adminUser.Id, updated.ReviewedByUserId);
            Assert.Equal("Đã xác nhận sự cố mạng, duyệt chấm công bổ sung", updated.ReviewNote);
            Assert.NotNull(updated.ReviewedAtUtc);
        }

        [Fact]
        public async Task Admin_RejectPendingAppeal_UpdatesStatus()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (adminUser, _, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);
            var assignment = new ShiftAssignment
            {
                Id = 231,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            var appeal = new AttendanceAppeal
            {
                Id = 501,
                EmployeeId = employee.Id,
                ShiftAssignmentId = assignment.Id,
                Reason = "Yêu cầu đang chờ xử lý",
                Status = "Pending"
            };
            db.Set<ShiftAssignment>().Add(assignment);
            db.Set<AttendanceAppeal>().Add(appeal);
            await db.SaveChangesAsync();

            var result = await CreateController(db, adminUser.Id, "Admin")
                .ReviewAppeal(appeal.Id, new ReviewAppealRequest
                {
                    Status = "Rejected",
                    ReviewNote = "Chưa đủ căn cứ"
                });

            Assert.IsType<OkObjectResult>(result);
            Assert.Equal("Rejected", appeal.Status);
            Assert.Equal(adminUser.Id, appeal.ReviewedByUserId);
            Assert.NotNull(appeal.ReviewedAtUtc);
        }

        [Theory]
        [InlineData("Approved")]
        [InlineData("Rejected")]
        public async Task Admin_ReviewProcessedAppeal_ReturnsConflict(string currentStatus)
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (adminUser, _, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);
            var assignment = new ShiftAssignment
            {
                Id = 230,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            var appeal = new AttendanceAppeal
            {
                Id = 500,
                EmployeeId = employee.Id,
                ShiftAssignmentId = assignment.Id,
                Reason = "Đã được xử lý",
                Status = currentStatus
            };
            db.Set<ShiftAssignment>().Add(assignment);
            db.Set<AttendanceAppeal>().Add(appeal);
            await db.SaveChangesAsync();

            var result = await CreateController(db, adminUser.Id, "Admin")
                .ReviewAppeal(appeal.Id, new ReviewAppealRequest
                {
                    Status = currentStatus == "Approved" ? "Rejected" : "Approved"
                });

            Assert.IsType<ConflictObjectResult>(result);
            Assert.Equal(currentStatus, appeal.Status);
        }

        [Fact]
        public void ReviewAppeal_RequiresAdminRole()
        {
            var method = typeof(AttendanceAppealsController)
                .GetMethod(nameof(AttendanceAppealsController.ReviewAppeal));
            Assert.NotNull(method);
            var authorize = Assert.Single(
                method.GetCustomAttributes(typeof(AuthorizeAttribute), true)
                    .Cast<AuthorizeAttribute>());
            Assert.Equal("Admin", authorize.Roles);
        }

        [Fact]
        public async Task GetAppealSuggestions_DetectsLateCheckInAndMissingCheckOut()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Ca 1: Di muon (CheckInStatus == "Late")
            var assignmentLate = new ShiftAssignment
            {
                Id = 31,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "Completed"
            };
            var recLate = new AttendanceRecord
            {
                Id = 101,
                ShiftAssignmentId = assignmentLate.Id,
                CheckInStatus = "Late",
                CheckInUtc = DateTimeOffset.UtcNow.AddHours(-4),
                CheckOutUtc = DateTimeOffset.UtcNow
            };
            assignmentLate.AttendanceRecord = recLate;
            db.Set<ShiftAssignment>().Add(assignmentLate);
            db.Set<AttendanceRecord>().Add(recLate);

            // Ca 2: Quen check-out (InProgress tu ngay hom qua)
            var yesterday = DateOnly.FromDateTime(DateTime.Today.AddDays(-1));
            var assignmentMissingOut = new ShiftAssignment
            {
                Id = 32,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = yesterday,
                Status = "InProgress"
            };
            db.Set<ShiftAssignment>().Add(assignmentMissingOut);

            await db.SaveChangesAsync();

            var controller = CreateController(db, empUser.Id, "Employee");
            var result = await controller.GetAppealSuggestions();
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);

            // Verify suggestions count
            var totalProp = okResult.Value.GetType().GetProperty("total");
            Assert.NotNull(totalProp);
            var totalVal = (int)totalProp.GetValue(okResult.Value)!;
            Assert.Equal(2, totalVal);
        }

        [Fact]
        public async Task GetAppealSuggestions_ProvidesNeutralTemplate_AndFiltersAppealedShifts()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var yesterday = DateOnly.FromDateTime(DateTime.Today.AddDays(-1));

            // Ca 1: MissedShift (Status Scheduled tu hom qua)
            var missedAssignment = new ShiftAssignment
            {
                Id = 41,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = yesterday,
                Status = "Scheduled"
            };

            // Ca 2: Vao muon nhung DA CO DON GIAI TRINH PENDING
            var alreadyAppealedAssignment = new ShiftAssignment
            {
                Id = 42,
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = yesterday,
                Status = "Completed"
            };
            var recLate = new AttendanceRecord
            {
                Id = 201,
                ShiftAssignmentId = alreadyAppealedAssignment.Id,
                CheckInStatus = "Late",
                CheckInUtc = DateTimeOffset.UtcNow.AddDays(-1),
                CheckOutUtc = DateTimeOffset.UtcNow.AddDays(-1).AddHours(8)
            };
            alreadyAppealedAssignment.AttendanceRecord = recLate;

            var existingPendingAppeal = new AttendanceAppeal
            {
                Id = 61,
                EmployeeId = employee.Id,
                ShiftAssignmentId = alreadyAppealedAssignment.Id,
                Reason = "Đã gửi đơn hôm qua",
                Status = "Pending"
            };

            db.Set<ShiftAssignment>().AddRange(missedAssignment, alreadyAppealedAssignment);
            db.Set<AttendanceRecord>().Add(recLate);
            db.Set<AttendanceAppeal>().Add(existingPendingAppeal);
            await db.SaveChangesAsync();

            var controller = CreateController(db, empUser.Id, "Employee");
            var result = await controller.GetAppealSuggestions();
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);

            var suggestionsProp = okResult.Value.GetType().GetProperty("suggestions");
            Assert.NotNull(suggestionsProp);
            var suggestions = suggestionsProp.GetValue(okResult.Value) as System.Collections.IEnumerable;
            Assert.NotNull(suggestions);

            var list = suggestions.Cast<object>().ToList();
            // Chi co missedAssignment duoc goi y (alreadyAppealedAssignment bi loai vi da co don Pending)
            Assert.Single(list);

            var firstSug = list[0];
            var anomalyTypeProp = firstSug.GetType().GetProperty("anomalyType");
            var suggestedReasonProp = firstSug.GetType().GetProperty("suggestedReason");
            Assert.NotNull(anomalyTypeProp);
            Assert.NotNull(suggestedReasonProp);

            Assert.Equal("MissedShift", anomalyTypeProp.GetValue(firstSug));
            var suggestedReason = (string)suggestedReasonProp.GetValue(firstSug)!;
            Assert.Contains("Tôi xin giải trình về trường hợp", suggestedReason);
            Assert.Contains("Lý do thực tế:", suggestedReason);
        }

        [Fact]
        public async Task GetAppealSuggestions_OvernightShift_StillActive_NotFlagged()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, _, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Ca qua dem: 22:00 -> 23:59:59 hom sau (dam bao shiftEndDateTime luon o tuong lai)
            var overnightShift = new Shift
            {
                Id = 99,
                Name = "Ca Đêm Đặc Biệt",
                StartTime = new TimeSpan(22, 0, 0),
                EndTime = new TimeSpan(23, 59, 59),
                GraceMinutes = 15,
                IsActive = true
            };
            // Thiet lap StartTime > EndTime de mo phong ca qua dem
            overnightShift.StartTime = new TimeSpan(23, 0, 0);
            overnightShift.EndTime = new TimeSpan(12, 0, 0); // 12:00 trua hom sau

            db.Set<Shift>().Add(overnightShift);

            // Ca bat dau hom nay, ket thuc 12:00 trua mai -> hien tai chac chan chua ket thuc
            var activeOvernight = new ShiftAssignment
            {
                Id = 991,
                EmployeeId = employee.Id,
                ShiftId = overnightShift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today),
                Status = "InProgress"
            };

            db.Set<ShiftAssignment>().Add(activeOvernight);
            await db.SaveChangesAsync();

            var controller = CreateController(db, empUser.Id, "Employee");
            var result = await controller.GetAppealSuggestions();
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);

            var totalProp = okResult.Value.GetType().GetProperty("total");
            Assert.NotNull(totalProp);
            var total = (int)totalProp.GetValue(okResult.Value)!;

            // Khong duoc canh bao vi ca qua dem chua ket thuc
            Assert.Equal(0, total);
        }

        [Fact]
        public async Task GetAppealSuggestions_OvernightShift_Ended_FlaggedAsMissingCheckOut()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, empUser, employee, _, _, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            // Ca qua dem: 22:00 -> 06:00
            var overnightShift = new Shift
            {
                Id = 98,
                Name = "Ca Đêm Đã Kết Thúc",
                StartTime = new TimeSpan(22, 0, 0),
                EndTime = new TimeSpan(6, 0, 0),
                GraceMinutes = 15,
                IsActive = true
            };
            db.Set<Shift>().Add(overnightShift);

            // Ca bat dau tu 3 ngay truoc -> ket thuc 2 ngay truoc
            var endedOvernight = new ShiftAssignment
            {
                Id = 981,
                EmployeeId = employee.Id,
                ShiftId = overnightShift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today.AddDays(-3)),
                Status = "InProgress"
            };

            db.Set<ShiftAssignment>().Add(endedOvernight);
            await db.SaveChangesAsync();

            var controller = CreateController(db, empUser.Id, "Employee");
            var result = await controller.GetAppealSuggestions();
            var okResult = Assert.IsType<OkObjectResult>(result);
            Assert.NotNull(okResult.Value);

            var totalProp = okResult.Value.GetType().GetProperty("total");
            Assert.NotNull(totalProp);
            var total = (int)totalProp.GetValue(okResult.Value)!;

            // Ca qua dem da ket thuc 2 ngay truoc -> phai duoc goi y MissingCheckOut
            Assert.Equal(1, total);
        }
    }
}
