
namespace ChamCong_PhanHuuVinh_2380602565_API.Services
{
    public interface IOtpService
    {
        // Tao va luu OTP, tra ma cho backend gui email.
        // Khong tra ma OTP ve response cua API.
        Task<string> CreateAsync(
            string userId,
            string purpose,
            CancellationToken cancellationToken = default);

        // Xac minh OTP, danh dau da su dung neu dung.
        Task<bool> VerifyAsync(
            string userId,
            string purpose,
            string code,
            CancellationToken cancellationToken = default);
    }
}
