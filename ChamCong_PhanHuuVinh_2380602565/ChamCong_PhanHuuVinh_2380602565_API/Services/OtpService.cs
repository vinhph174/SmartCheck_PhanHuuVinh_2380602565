
using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Services
{
    public class OtpService : IOtpService
    {
        private const int ExpiryMinutes = 5;
        private const int MaxAttempts = 5;
        private const int ResendCooldownSeconds = 60;
        private const int MaxIssuesPerHour = 5;

        private readonly ApplicationDbContext _db;
        private readonly byte[] _otpKey;

        public OtpService(
            ApplicationDbContext db,
            IConfiguration configuration)
        {
            _db = db;

            var keyBase64 = configuration["Otp:Key"]
                ?? throw new InvalidOperationException(
                    "Thiếu Otp:Key trong cấu hình");

            try
            {
                _otpKey = Convert.FromBase64String(keyBase64);
            }
            catch (FormatException ex)
            {
                throw new InvalidOperationException(
                    "Otp:Key phải là Base64 hợp lệ", ex);
            }

            if (_otpKey.Length < 32)
            {
                throw new InvalidOperationException(
                    "Otp:Key phải có ít nhất 32 byte");
            }
        }

        // Chi chap nhan 2 muc dich OTP cua SmartCheck.
        private static void ValidatePurpose(string purpose)
        {
            if (purpose != "Login" &&
                purpose != "VerifyEmail")
            {
                throw new ArgumentException(
                    "Mục đích OTP không hợp lệ",
                    nameof(purpose));
            }
        }

        // Tao HMAC cho OTP, gan voi tai khoan,
        // muc dich va tung lan yeu cau.
        private byte[] ComputeHash(
            Guid challengeId,
            string userId,
            string purpose,
            string code)
        {
            var payload = Encoding.UTF8.GetBytes(
                $"{challengeId:N}:{userId}:{purpose}:{code}");

            return HMACSHA256.HashData(_otpKey, payload);
        }

        // =====================================
        // TAO OTP MOI
        // =====================================
        public async Task<string> CreateAsync(
            string userId,
            string purpose,
            CancellationToken cancellationToken = default)
        {
            ValidatePurpose(purpose);

            if (string.IsNullOrWhiteSpace(userId))
                throw new ArgumentException(
                    "UserId không hợp lệ", nameof(userId));

            var now = DateTimeOffset.UtcNow;

            // Transaction giup kiem tra gioi han
            // va tao OTP trong cung mot giao dich.
            await using var transaction =
                await _db.Database.BeginTransactionAsync(
                    IsolationLevel.Serializable,
                    cancellationToken);

            var query = _db.Set<OtpChallenge>()
                .Where(x =>
                    x.ApplicationUserId == userId &&
                    x.Purpose == purpose);

            // Toi da 5 lan cap OTP trong mot gio.
            var countLastHour = await query.CountAsync(
                x => x.CreatedAtUtc >= now.AddHours(-1),
                cancellationToken);

            if (countLastHour >= MaxIssuesPerHour)
            {
                throw new InvalidOperationException(
                    "Đã vượt giới hạn cấp OTP. Thử lại sau.");
            }

            // Phai cho it nhat 60 giay de yeu cau lai.
            var latestIssue = await query
                .OrderByDescending(x => x.CreatedAtUtc)
                .Select(x => (DateTimeOffset?)x.CreatedAtUtc)
                .FirstOrDefaultAsync(cancellationToken);

            if (latestIssue.HasValue &&
                latestIssue.Value >
                    now.AddSeconds(-ResendCooldownSeconds))
            {
                throw new InvalidOperationException(
                    "Vui lòng đợi 60 giây trước khi xin OTP mới.");
            }

            // OTP bao mat tu RandomNumberGenerator.
            var code = RandomNumberGenerator
                .GetInt32(0, 1_000_000)
                .ToString("D6", CultureInfo.InvariantCulture);

            var challenge = new OtpChallenge
            {
                Id = Guid.NewGuid(),
                ApplicationUserId = userId,
                Purpose = purpose,
                CreatedAtUtc = now,
                ExpiresAtUtc = now.AddMinutes(ExpiryMinutes),
                AttemptCount = 0
            };

            challenge.CodeHash = Convert.ToHexString(
                ComputeHash(
                    challenge.Id, userId, purpose, code));

            // Huy hieu luc OTP cu neu con hieu luc.
            await query
                .Where(x =>
                    x.ConsumedAtUtc == null &&
                    x.ExpiresAtUtc > now)
                .ExecuteUpdateAsync(
                    setters => setters.SetProperty(
                        x => x.ConsumedAtUtc,
                        (DateTimeOffset?)now),
                    cancellationToken);

            _db.Set<OtpChallenge>().Add(challenge);

            await _db.SaveChangesAsync(cancellationToken);

            await transaction.CommitAsync(cancellationToken);

            // Chi tra OTP cho code backend de gui mail.
            return code;
        }

        // =====================================
        // KIEM TRA OTP
        // =====================================
        public async Task<bool> VerifyAsync(
            string userId,
            string purpose,
            string code,
            CancellationToken cancellationToken = default)
        {
            ValidatePurpose(purpose);

            if (string.IsNullOrWhiteSpace(userId) ||
                code == null ||
                code.Length != 6 ||
                code.Any(c => c < '0' || c > '9'))
            {
                return false;
            }

            var now = DateTimeOffset.UtcNow;

            // Lay OTP moi nhat cua dung tai khoan
            // va dung muc dich.
            var challenge = await _db.Set<OtpChallenge>()
                .AsNoTracking()
                .Where(x =>
                    x.ApplicationUserId == userId &&
                    x.Purpose == purpose)
                .OrderByDescending(x => x.CreatedAtUtc)
                .ThenByDescending(x => x.Id)
                .FirstOrDefaultAsync(cancellationToken);

            if (challenge == null ||
                challenge.ConsumedAtUtc != null ||
                challenge.ExpiresAtUtc <= now ||
                challenge.AttemptCount >= MaxAttempts)
            {
                return false;
            }

            var expectedHash = ComputeHash(
                challenge.Id,
                userId,
                purpose,
                code);

            var storedHash = Convert.FromHexString(
                challenge.CodeHash);

            // So sanh hash theo thoi gian hang dinh.
            var isValid = CryptographicOperations
                .FixedTimeEquals(expectedHash, storedHash);

            // Dieu kien update giup chan hai request
            // su dung cung mot OTP thanh cong.
            var activeChallenge = _db.Set<OtpChallenge>()
                .Where(x =>
                    x.Id == challenge.Id &&
                    x.ConsumedAtUtc == null &&
                    x.ExpiresAtUtc > now &&
                    x.AttemptCount < MaxAttempts);

            if (!isValid)
            {
                // Tang so lan nhap sai truc tiep trong DB.
                await activeChallenge.ExecuteUpdateAsync(
                    setters => setters.SetProperty(
                        x => x.AttemptCount,
                        x => x.AttemptCount + 1),
                    cancellationToken);

                return false;
            }

            // Danh dau da su dung theo kieu atomic.
            var updated = await activeChallenge
                .ExecuteUpdateAsync(
                    setters => setters.SetProperty(
                        x => x.ConsumedAtUtc,
                        (DateTimeOffset?)now),
                    cancellationToken);

            return updated == 1;
        }
    }
}
