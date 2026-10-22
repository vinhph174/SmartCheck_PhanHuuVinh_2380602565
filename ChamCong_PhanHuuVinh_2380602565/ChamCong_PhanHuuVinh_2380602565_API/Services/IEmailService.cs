
namespace ChamCong_PhanHuuVinh_2380602565_API.Services
{
    public interface IEmailService
    {
        // Gửi email đến người nhận
        Task SendEmailAsync(
            string toEmail,
            string subject,
            string body,
            CancellationToken cancellationToken = default);
    }
}
