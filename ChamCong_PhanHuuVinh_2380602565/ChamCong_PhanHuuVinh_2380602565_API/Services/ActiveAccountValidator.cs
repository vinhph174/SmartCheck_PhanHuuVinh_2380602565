using System.Security.Claims;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using Microsoft.EntityFrameworkCore;

namespace ChamCong_PhanHuuVinh_2380602565_API.Services;

public interface IActiveAccountValidator
{
    Task<bool> IsActiveAsync(
        ClaimsPrincipal principal,
        CancellationToken cancellationToken = default);
}

public sealed class ActiveAccountValidator : IActiveAccountValidator
{
    private readonly ApplicationDbContext _db;

    public ActiveAccountValidator(ApplicationDbContext db)
    {
        _db = db;
    }

    public async Task<bool> IsActiveAsync(
        ClaimsPrincipal principal,
        CancellationToken cancellationToken = default)
    {
        var userId = principal.FindFirstValue(ClaimTypes.NameIdentifier);
        if (string.IsNullOrWhiteSpace(userId))
        {
            return false;
        }

        var userIsActive = await _db.Users
            .AsNoTracking()
            .Where(user => user.Id == userId)
            .Select(user => user.IsActive)
            .SingleOrDefaultAsync(cancellationToken);

        if (!userIsActive)
        {
            return false;
        }

        // Tài khoản nhân viên chỉ hợp lệ khi cả tài khoản Identity và hồ sơ
        // nghiệp vụ đều đang hoạt động.
        if (principal.IsInRole("Employee"))
        {
            return await _db.Employees
                .AsNoTracking()
                .AnyAsync(
                    employee => employee.ApplicationUserId == userId &&
                                employee.IsActive,
                    cancellationToken);
        }

        return true;
    }
}
