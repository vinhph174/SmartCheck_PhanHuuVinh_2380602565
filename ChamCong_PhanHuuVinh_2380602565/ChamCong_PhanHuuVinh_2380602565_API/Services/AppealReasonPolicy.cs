namespace ChamCong_PhanHuuVinh_2380602565_API.Services;

public static class AppealReasonPolicy
{
    private const string ActualReasonMarker = "lý do thực tế:";

    public static string? Validate(string? value)
    {
        var reason = value?.Trim() ?? string.Empty;
        if (reason.Length < 5)
        {
            return "Lý do giải trình phải từ 5 ký tự trở lên.";
        }

        var markerIndex = reason.LastIndexOf(
            ActualReasonMarker,
            StringComparison.OrdinalIgnoreCase);

        if (markerIndex >= 0)
        {
            var actualReason = reason[
                (markerIndex + ActualReasonMarker.Length)..].Trim();
            if (actualReason.Length < 3)
            {
                return "Vui lòng nhập lý do thực tế sau phần gợi ý.";
            }
        }

        return null;
    }
}
