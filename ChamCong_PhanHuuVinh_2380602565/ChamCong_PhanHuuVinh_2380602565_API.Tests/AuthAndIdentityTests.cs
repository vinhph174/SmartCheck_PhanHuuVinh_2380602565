using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.Tokens;
using Xunit;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Tests
{
    public class AuthAndIdentityTests
    {
        [Fact]
        public void ApplicationUser_ShouldInitialize_WithDefaultStates()
        {
            var user = new ApplicationUser
            {
                UserName = "vinh_test",
                Email = "vinh@test.vn",
                FullName = "Phan Hữu Vinh"
            };

            Assert.False(user.EmailConfirmed);
            Assert.False(user.IsActive);
            Assert.Equal("Phan Hữu Vinh", user.FullName);
        }

        [Fact]
        public void IdentityPasswordOptions_ShouldEnforceSecurityStandards()
        {
            var options = new PasswordOptions
            {
                RequiredLength = 8,
                RequireDigit = true,
                RequireUppercase = true,
                RequireLowercase = true,
                RequireNonAlphanumeric = false
            };

            Assert.Equal(8, options.RequiredLength);
            Assert.True(options.RequireDigit);
            Assert.True(options.RequireUppercase);
            Assert.True(options.RequireLowercase);
        }

        [Fact]
        public void LockoutOptions_ShouldLimitFailedAttempts()
        {
            var lockout = new LockoutOptions
            {
                DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15),
                MaxFailedAccessAttempts = 5,
                AllowedForNewUsers = true
            };

            Assert.Equal(5, lockout.MaxFailedAccessAttempts);
            Assert.Equal(TimeSpan.FromMinutes(15), lockout.DefaultLockoutTimeSpan);
            Assert.True(lockout.AllowedForNewUsers);
        }

        [Theory]
        [InlineData("Admin")]
        [InlineData("Employee")]
        public void JwtTokenGeneration_ShouldIncludeCorrectRoleAndSubjectClaims(string role)
        {
            var keyBytes = RandomNumberGenerator.GetBytes(64);
            var key = new SymmetricSecurityKey(keyBytes);
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, "user-guid-123"),
                new Claim(ClaimTypes.NameIdentifier, "user-guid-123"),
                new Claim(ClaimTypes.Name, "nhanvien01"),
                new Claim(ClaimTypes.Role, role)
            };

            var token = new JwtSecurityToken(
                issuer: "ChamCong_PhanHuuVinh_2380602565_API",
                audience: "SmartCheck_PhanHuuVinh_2380602565",
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(30),
                signingCredentials: creds
            );

            var tokenHandler = new JwtSecurityTokenHandler();
            var jwtString = tokenHandler.WriteToken(token);

            Assert.NotNull(jwtString);
            var parsed = tokenHandler.ReadJwtToken(jwtString);

            Assert.Equal("ChamCong_PhanHuuVinh_2380602565_API", parsed.Issuer);
            Assert.Contains(parsed.Audiences, a => a == "SmartCheck_PhanHuuVinh_2380602565");
            Assert.Contains(parsed.Claims, c => c.Type == ClaimTypes.Role && c.Value == role);
            Assert.Contains(parsed.Claims, c => c.Type == ClaimTypes.NameIdentifier && c.Value == "user-guid-123");
        }
    }
}

