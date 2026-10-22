
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace ChamCong_PhanHuuVinh_2380602565_API.Services
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _configuration;

        public EmailService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task SendEmailAsync(
            string toEmail,
            string subject,
            string body,
            CancellationToken cancellationToken = default)
        {
            var host = _configuration["Email:SmtpHost"]
                ?? throw new InvalidOperationException(
                    "Chưa cấu hình máy chủ SMTP");

            var port = _configuration.GetValue<int>(
                "Email:SmtpPort");

            var user = _configuration["Email:SmtpUser"];
            if (string.IsNullOrWhiteSpace(user))
            {
                user = _configuration["AdminBootstrap:Email"];
            }

            if (string.IsNullOrWhiteSpace(user))
            {
                throw new InvalidOperationException(
                    "Chưa cấu hình tài khoản SMTP");
            }

            var password = _configuration["Email:SmtpPassword"];
            if (string.IsNullOrWhiteSpace(password))
            {
                throw new InvalidOperationException(
                    "Chưa cấu hình mật khẩu SMTP");
            }

            var senderName = _configuration["Email:SenderName"]
                ?? "Chấm Công Thông Minh";

            var message = new MimeMessage();

            message.From.Add(
                new MailboxAddress(senderName, user));

            message.To.Add(
                MailboxAddress.Parse(toEmail));

            message.Subject = subject;

            message.Body = new TextPart("plain")
            {
                Text = body
            };

            using var client = new SmtpClient();

            await client.ConnectAsync(
                host,
                port,
                SecureSocketOptions.StartTls,
                cancellationToken);

            await client.AuthenticateAsync(
                user,
                password,
                cancellationToken);

            await client.SendAsync(
                message,
                cancellationToken);

            await client.DisconnectAsync(
                true,
                cancellationToken);
        }
    }
}
