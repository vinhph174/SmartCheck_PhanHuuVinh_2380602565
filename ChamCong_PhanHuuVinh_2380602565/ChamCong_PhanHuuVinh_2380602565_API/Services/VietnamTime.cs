namespace ChamCong_PhanHuuVinh_2380602565_API.Services;

public static class VietnamTime
{
    private static readonly Lazy<TimeZoneInfo> TimeZone = new(ResolveTimeZone);

    public static DateTimeOffset Now => ToLocal(DateTimeOffset.UtcNow);

    public static DateTimeOffset ToLocal(DateTimeOffset instant)
    {
        return TimeZoneInfo.ConvertTime(instant, TimeZone.Value);
    }

    public static DateOnly Today(DateTimeOffset instant)
    {
        return DateOnly.FromDateTime(ToLocal(instant).DateTime);
    }

    public static DateTime GetShiftEnd(
        DateOnly workDate,
        TimeSpan startTime,
        TimeSpan endTime)
    {
        var endDate = endTime < startTime ? workDate.AddDays(1) : workDate;
        return endDate.ToDateTime(TimeOnly.FromTimeSpan(endTime));
    }

    private static TimeZoneInfo ResolveTimeZone()
    {
        foreach (var id in new[] { "Asia/Ho_Chi_Minh", "SE Asia Standard Time" })
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(id);
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        // Việt Nam không áp dụng DST; offset cố định là fallback an toàn cho
        // các runtime tối giản không đóng gói timezone database.
        return TimeZoneInfo.CreateCustomTimeZone(
            "Vietnam Standard Time",
            TimeSpan.FromHours(7),
            "Vietnam Standard Time",
            "Vietnam Standard Time");
    }
}
