using System.Security.Claims;
using ChamCong_PhanHuuVinh_2380602565_API.Models;
using ChamCong_PhanHuuVinh_2380602565_API.Services;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests;

public class SecurityAndTimeTests
{
    private static ClaimsPrincipal Principal(string userId, string role)
    {
        return new ClaimsPrincipal(new ClaimsIdentity(
            new[]
            {
                new Claim(ClaimTypes.NameIdentifier, userId),
                new Claim(ClaimTypes.Role, role)
            },
            "TestAuth"));
    }

    [Fact]
    public async Task ActiveAccountValidator_AcceptsActiveAdminAndEmployee()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var (admin, employeeUser, _, _, _, _) = await TestDbHelper.SeedBasicDataAsync(db);
        var validator = new ActiveAccountValidator(db);

        Assert.True(await validator.IsActiveAsync(Principal(admin.Id, "Admin")));
        Assert.True(await validator.IsActiveAsync(Principal(employeeUser.Id, "Employee")));
    }

    [Fact]
    public async Task ActiveAccountValidator_RejectsInactiveIdentityOrEmployeeProfile()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var (_, employeeUser, employee, _, _, _) = await TestDbHelper.SeedBasicDataAsync(db);
        var validator = new ActiveAccountValidator(db);

        employee.IsActive = false;
        await db.SaveChangesAsync();
        Assert.False(await validator.IsActiveAsync(Principal(employeeUser.Id, "Employee")));

        employee.IsActive = true;
        employeeUser.IsActive = false;
        await db.SaveChangesAsync();
        Assert.False(await validator.IsActiveAsync(Principal(employeeUser.Id, "Employee")));
    }

    [Fact]
    public async Task ActiveAccountValidator_RejectsMissingAccount()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var validator = new ActiveAccountValidator(db);

        Assert.False(await validator.IsActiveAsync(Principal("missing", "Admin")));
    }

    [Fact]
    public void AttendanceAppealStatus_IsConcurrencyToken()
    {
        using var db = TestDbHelper.CreateInMemoryDbContext();
        var property = db.Model.FindEntityType(typeof(AttendanceAppeal))!
            .FindProperty(nameof(AttendanceAppeal.Status));

        Assert.NotNull(property);
        Assert.True(property.IsConcurrencyToken);
    }

    [Fact]
    public void VietnamToday_UsesUtcPlusSevenAtDayBoundary()
    {
        var beforeVietnamMidnight = new DateTimeOffset(2026, 10, 21, 16, 59, 0, TimeSpan.Zero);
        var afterVietnamMidnight = beforeVietnamMidnight.AddMinutes(2);

        Assert.Equal(new DateOnly(2026, 10, 21), VietnamTime.Today(beforeVietnamMidnight));
        Assert.Equal(new DateOnly(2026, 10, 22), VietnamTime.Today(afterVietnamMidnight));
    }

    [Fact]
    public void OvernightShift_EndsOnFollowingWorkDate()
    {
        var workDate = new DateOnly(2026, 10, 22);

        var end = VietnamTime.GetShiftEnd(
            workDate,
            new TimeSpan(22, 0, 0),
            new TimeSpan(6, 0, 0));

        Assert.Equal(new DateTime(2026, 10, 23, 6, 0, 0), end);
    }

    [Fact]
    public void AppealReasonPolicy_RequiresEmployeeToCompleteSuggestedTemplate()
    {
        Assert.NotNull(AppealReasonPolicy.Validate(
            "Tôi xin giải trình về trường hợp đi muộn. Lý do thực tế: "));
        Assert.Null(AppealReasonPolicy.Validate(
            "Tôi xin giải trình về trường hợp đi muộn. Lý do thực tế: Xe bị hỏng."));
    }
}
