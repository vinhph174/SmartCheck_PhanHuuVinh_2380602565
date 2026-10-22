using Microsoft.AspNetCore.Mvc;
using Xunit;
using ChamCong_PhanHuuVinh_2380602565_API.Controllers;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests
{
    public class ShiftAssignmentTests
    {
        [Fact]
        public async Task AssignShift_WithValidData_ReturnsCreated()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, _, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var controller = new ShiftAssignmentsController(db);

            var req = new ShiftAssignmentRequest
            {
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today)
            };

            var actionResult = await controller.Create(req);
            Assert.IsType<CreatedAtActionResult>(actionResult);

            var inDb = db.Set<ShiftAssignment>().FirstOrDefault(s =>
                s.EmployeeId == employee.Id &&
                s.ShiftId == shift.Id &&
                s.WorkDate == req.WorkDate);

            Assert.NotNull(inDb);
            Assert.Equal("Scheduled", inDb.Status);
        }

        [Fact]
        public async Task AssignShift_DuplicateShiftInSameDay_ReturnsConflict()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, _, employee, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var controller = new ShiftAssignmentsController(db);
            var today = DateOnly.FromDateTime(DateTime.Today);

            var req1 = new ShiftAssignmentRequest
            {
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = today
            };

            // First assignment succeeds
            var res1 = await controller.Create(req1);
            Assert.IsType<CreatedAtActionResult>(res1);

            // Second assignment with same employee, shift and date must fail with Conflict (409)
            var req2 = new ShiftAssignmentRequest
            {
                EmployeeId = employee.Id,
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = today
            };

            var res2 = await controller.Create(req2);
            Assert.IsType<ConflictObjectResult>(res2);
        }

        [Fact]
        public async Task AssignShift_WithNonExistentEmployee_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, _, _, _, shift, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var controller = new ShiftAssignmentsController(db);

            var req = new ShiftAssignmentRequest
            {
                EmployeeId = 9999, // Non-existent employee
                ShiftId = shift.Id,
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today)
            };

            var actionResult = await controller.Create(req);
            Assert.IsType<BadRequestObjectResult>(actionResult);
        }

        [Fact]
        public async Task AssignShift_WithNonExistentShift_ReturnsBadRequest()
        {
            using var db = TestDbHelper.CreateInMemoryDbContext();
            var (_, _, employee, _, _, loc) = await TestDbHelper.SeedBasicDataAsync(db);

            var controller = new ShiftAssignmentsController(db);

            var req = new ShiftAssignmentRequest
            {
                EmployeeId = employee.Id,
                ShiftId = 8888, // Non-existent shift
                WorkLocationId = loc.Id,
                WorkDate = DateOnly.FromDateTime(DateTime.Today)
            };

            var actionResult = await controller.Create(req);
            Assert.IsType<BadRequestObjectResult>(actionResult);
        }
    }
}

