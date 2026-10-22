using System.Security.Claims;
using System.Text.Json;
using ChamCong_PhanHuuVinh_2380602565_API.Controllers;
using ChamCong_PhanHuuVinh_2380602565_API.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging.Abstractions;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests;

public class CrudLifecycleTests
{
    [Fact]
    public async Task Department_CreateReadUpdateDelete_LifecycleSucceeds()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var controller = new ManagementCrudController(db);

        Assert.IsType<CreatedResult>(await controller.CreateDepartment(
            new DepartmentCrudRequest { Name = "Phòng mới", IsActive = true }));
        var item = Assert.Single(db.Set<Department>());
        Assert.IsType<OkObjectResult>(await controller.GetDepartment(item.Id));
        Assert.IsType<OkObjectResult>(await controller.UpdateDepartment(
            item.Id,
            new DepartmentCrudRequest { Name = "Phòng đã sửa", IsActive = true }));
        Assert.Equal("Phòng đã sửa", item.Name);
        Assert.IsType<NoContentResult>(await controller.DeleteDepartment(item.Id));
        Assert.Empty(db.Set<Department>());
    }

    [Fact]
    public async Task Shift_CreateReadUpdateDelete_LifecycleSucceeds()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var controller = new ManagementCrudController(db);
        var request = new ShiftCrudRequest
        {
            Name = "Ca đêm",
            StartTime = new TimeSpan(22, 0, 0),
            EndTime = new TimeSpan(6, 0, 0),
            GraceMinutes = 10,
            IsActive = true
        };

        Assert.IsType<CreatedResult>(await controller.CreateShift(request));
        var item = Assert.Single(db.Set<Shift>());
        Assert.IsType<OkObjectResult>(await controller.GetShift(item.Id));
        request.GraceMinutes = 15;
        Assert.IsType<OkObjectResult>(await controller.UpdateShift(item.Id, request));
        Assert.Equal(15, item.GraceMinutes);
        Assert.IsType<NoContentResult>(await controller.DeleteShift(item.Id));
    }

    [Fact]
    public async Task Location_CreateReadUpdateDelete_LifecycleSucceeds()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var controller = new ManagementCrudController(db);
        var request = new WorkLocationCrudRequest
        {
            Name = "Văn phòng",
            Address = "TP.HCM",
            Latitude = 10.77m,
            Longitude = 106.70m,
            AllowedRadiusMeters = 200,
            IsActive = true
        };

        Assert.IsType<CreatedResult>(await controller.CreateLocation(request));
        var item = Assert.Single(db.Set<WorkLocation>());
        Assert.IsType<OkObjectResult>(await controller.GetLocation(item.Id));
        request.AllowedRadiusMeters = 250;
        Assert.IsType<OkObjectResult>(await controller.UpdateLocation(item.Id, request));
        Assert.Equal(250, item.AllowedRadiusMeters);
        Assert.IsType<NoContentResult>(await controller.DeleteLocation(item.Id));
    }

    [Fact]
    public async Task Assignment_CreateReadUpdateDelete_LifecycleSucceeds()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var (_, _, employee, _, shift, location) =
            await TestDbHelper.SeedBasicDataAsync(db);
        var controller = new ShiftAssignmentsController(db);
        var request = new ShiftAssignmentRequest
        {
            EmployeeId = employee.Id,
            ShiftId = shift.Id,
            WorkLocationId = location.Id,
            WorkDate = new DateOnly(2026, 11, 1)
        };

        Assert.IsType<CreatedAtActionResult>(await controller.Create(request));
        var item = Assert.Single(db.Set<ShiftAssignment>());
        Assert.IsType<OkObjectResult>(await controller.GetById(item.Id));
        request.WorkDate = request.WorkDate.AddDays(1);
        Assert.IsType<OkObjectResult>(await controller.Update(item.Id, request));
        Assert.Equal(request.WorkDate, item.WorkDate);
        Assert.IsType<NoContentResult>(await controller.Delete(item.Id));
    }

    [Fact]
    public async Task Employee_ReadUpdateAndDeactivate_PreservesRecord()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var (_, _, employee, _, _, _) = await TestDbHelper.SeedBasicDataAsync(db);
        var controller = new AdminController(
            db,
            NullLogger<AdminController>.Instance);
        controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext
            {
                User = new ClaimsPrincipal(new ClaimsIdentity(
                    new[]
                    {
                        new Claim(ClaimTypes.NameIdentifier, "admin-test-id"),
                        new Claim(ClaimTypes.Role, "Admin")
                    },
                    "TestAuth"))
            }
        };

        Assert.IsType<OkObjectResult>(await controller.GetEmployeeById(employee.Id));
        Assert.IsType<OkObjectResult>(await controller.UpdateEmployee(
            employee.Id,
            new UpdateEmployeeRequest
            {
                FullName = "Tên đã cập nhật",
                ClearDepartment = true
            }));
        Assert.Equal("Tên đã cập nhật", employee.ApplicationUser.FullName);
        Assert.Null(employee.DepartmentId);

        Assert.IsType<OkObjectResult>(await controller.DeactivateEmployee(employee.Id));
        Assert.False(employee.IsActive);
        Assert.False(employee.ApplicationUser.IsActive);
        Assert.Single(db.Set<Employee>());
    }

    [Fact]
    public async Task EmployeeActiveFilter_RequiresBothEmployeeAndUserToBeActive()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var (_, employeeUser, _, _, _, _) =
            await TestDbHelper.SeedBasicDataAsync(db);
        employeeUser.IsActive = false;
        await db.SaveChangesAsync();
        var controller = new AdminController(
            db,
            NullLogger<AdminController>.Instance);

        var activeResult = Assert.IsType<OkObjectResult>(
            await controller.GetAllEmployees(null, true));
        var inactiveResult = Assert.IsType<OkObjectResult>(
            await controller.GetAllEmployees(null, false));

        var activeJson = JsonSerializer.SerializeToElement(activeResult.Value);
        var inactiveJson = JsonSerializer.SerializeToElement(inactiveResult.Value);
        Assert.Equal(0, activeJson.GetProperty("total").GetInt32());
        Assert.Equal(1, inactiveJson.GetProperty("total").GetInt32());
    }
}
