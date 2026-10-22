
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

using ChamCong_PhanHuuVinh_2380602565_API.Data;
using ChamCong_PhanHuuVinh_2380602565_API.Models;
using ChamCong_PhanHuuVinh_2380602565_API.Services;

var builder = WebApplication.CreateBuilder(args);

// ========================================
// 1. KET NOI SQL SERVER
// ========================================

var connectionString = builder.Configuration
    .GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException(
        "Chưa cấu hình DefaultConnection");

builder.Services.AddDbContext<ApplicationDbContext>(
    options => options.UseSqlServer(connectionString)
);

// ========================================
// 2. CAU HINH ASP.NET CORE IDENTITY
// ========================================

builder.Services
    .AddIdentityCore<ApplicationUser>(options =>
    {
        // Email phai duy nhat
        options.User.RequireUniqueEmail = true;

        // Quy dinh mat khau
        options.Password.RequiredLength = 8;
        options.Password.RequireDigit = true;
        options.Password.RequireUppercase = true;
        options.Password.RequireLowercase = true;
        options.Password.RequireNonAlphanumeric = false;

        // Yeu cau xac minh email
        options.SignIn.RequireConfirmedEmail = true;

        // Gioi han dang nhap sai
        options.Lockout.DefaultLockoutTimeSpan =
            TimeSpan.FromMinutes(15);

        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.AllowedForNewUsers = true;
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<ApplicationDbContext>()
    .AddDefaultTokenProviders();

// ========================================
// 3. DOC CAU HINH JWT
// ========================================

var jwtIssuer = builder.Configuration["Jwt:Issuer"]
    ?? throw new InvalidOperationException(
        "Thiếu Jwt:Issuer");

var jwtAudience = builder.Configuration["Jwt:Audience"]
    ?? throw new InvalidOperationException(
        "Thiếu Jwt:Audience");

// Khoa JWT lay tu cau hinh bao mat
var jwtKeyBase64 = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException(
        "Thiếu Jwt:Key trong cấu hình");

byte[] jwtKeyBytes;

try
{
    jwtKeyBytes = Convert.FromBase64String(jwtKeyBase64);
}
catch (FormatException ex)
{
    throw new InvalidOperationException(
        "Jwt:Key phải là chuỗi Base64 hợp lệ", ex);
}

if (jwtKeyBytes.Length < 32)
{
    throw new InvalidOperationException(
        "Khóa JWT phải có ít nhất 32 byte");
}

// ========================================
// 4. CAU HINH JWT AUTHENTICATION
// ========================================

builder.Services.AddScoped<IActiveAccountValidator, ActiveAccountValidator>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = true;
        options.SaveToken = false;

        options.TokenValidationParameters =
            new TokenValidationParameters
            {
                // Kiem tra don vi phat hanh
                ValidateIssuer = true,
                ValidIssuer = jwtIssuer,

                // Kiem tra ung dung su dung
                ValidateAudience = true,
                ValidAudience = jwtAudience,

                // Kiem tra thoi han token
                ValidateLifetime = true,

                // Kiem tra chu ky JWT
                ValidateIssuerSigningKey = true,
                IssuerSigningKey =
                    new SymmetricSecurityKey(jwtKeyBytes),

                // Khong cong them thoi gian hieu luc
                ClockSkew = TimeSpan.Zero
            };

        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var validator = context.HttpContext.RequestServices
                    .GetRequiredService<IActiveAccountValidator>();

                if (context.Principal == null ||
                    !await validator.IsActiveAsync(
                        context.Principal,
                        context.HttpContext.RequestAborted))
                {
                    context.Fail("Tài khoản không còn hoạt động.");
                }
            }
        };
    });

// ========================================
// 5. CAU HINH PHAN QUYEN
// ========================================

builder.Services.AddAuthorization();

// ========================================
// 6. BAO VE PHIEN DANG NHAP HAI BUOC
// ========================================

// Bao ve LoginTicket sau khi nguoi dung
// nhap dung username va password.
//
// LoginTicket duoc su dung cung OTP de
// xac minh truoc khi cap JWT chinh thuc.

builder.Services.AddDataProtection();

// ========================================
// 7. DANG KY DICH VU EMAIL VA OTP
// ========================================

// Dich vu gui email bang Gmail SMTP
builder.Services.AddScoped<IEmailService, EmailService>();

// Dich vu tao, luu va xac minh OTP
builder.Services.AddScoped<IOtpService, OtpService>();

// ========================================
// 8. DANG KY CONTROLLERS VA SWAGGER
// ========================================

var allowedCorsOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? Array.Empty<string>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            policy.AllowAnyOrigin()
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
        else if (allowedCorsOrigins.Length > 0)
        {
            policy.WithOrigins(allowedCorsOrigins)
                  .AllowAnyMethod()
                  .AllowAnyHeader();
        }
    });
});

builder.Services
    .AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = _ =>
            new Microsoft.AspNetCore.Mvc.BadRequestObjectResult(new
            {
                message = "Dữ liệu gửi lên không hợp lệ. Vui lòng kiểm tra lại các trường."
            });
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddHealthChecks();

// ========================================
// 8.1. CAU HINH SWAGGER JWT AUTHORIZE
// ========================================

builder.Services.AddSwaggerGen(options =>
{
    // Khai bao cach xac thuc JWT Bearer
    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Name = "Authorization",

            Type = SecuritySchemeType.Http,

            Scheme = "bearer",

            BearerFormat = "JWT",

            In = ParameterLocation.Header,

            Description =
                "Nhap JWT Access Token sau khi " +
                "dang nhap va xac minh OTP."
        });

    // Cho phep Swagger gui JWT vao request
    options.AddSecurityRequirement(
        new OpenApiSecurityRequirement
        {
            {
                new OpenApiSecurityScheme
                {
                    Reference = new OpenApiReference
                    {
                        Type = ReferenceType.SecurityScheme,
                        Id = "Bearer"
                    }
                },
                Array.Empty<string>()
            }
        });
});

// ========================================
// 9. KHOI TAO UNG DUNG
// ========================================

var app = builder.Build();

// ========================================
// 10. KHOI TAO ROLE ADMIN VA EMPLOYEE
// ========================================

using (var scope = app.Services.CreateScope())
{
    var roleManager = scope.ServiceProvider
        .GetRequiredService<RoleManager<IdentityRole>>();

    // Hai vai tro cua SmartCheck
    string[] roles = { "Admin", "Employee" };

    foreach (var roleName in roles)
    {
        // Chi tao role khi chua ton tai
        if (!await roleManager.RoleExistsAsync(roleName))
        {
            var result = await roleManager.CreateAsync(
                new IdentityRole(roleName));

            if (!result.Succeeded)
            {
                var errors = string.Join(", ",
                    result.Errors.Select(e => e.Description));

                throw new InvalidOperationException(
                    $"Không tạo được vai trò {roleName}: {errors}");
            }
        }
    }

    // ========================================
    // 11. KHOI TAO ADMIN DAU TIEN
    // ========================================

    // Chi cho phep bootstrap trong Development
    // va khi duoc bat ro rang trong cau hinh.

    var enableAdminBootstrap =
        app.Environment.IsDevelopment() &&
        builder.Configuration.GetValue<bool>(
            "AdminBootstrap:Enabled");

    if (enableAdminBootstrap)
    {
        var userManager = scope.ServiceProvider
            .GetRequiredService<UserManager<ApplicationUser>>();

        var db = scope.ServiceProvider
            .GetRequiredService<ApplicationDbContext>();

        // Kiem tra da co Admin hay chua
        var existingAdmins =
            await userManager.GetUsersInRoleAsync("Admin");

        if (existingAdmins.Count == 0)
        {
            // Doc thong tin Admin tu User Secrets
            var adminUserName =
                builder.Configuration["AdminBootstrap:UserName"];

            var adminEmail =
                builder.Configuration["AdminBootstrap:Email"];

            var adminPassword =
                builder.Configuration["AdminBootstrap:Password"];

            // Kiem tra cau hinh bat buoc
            if (string.IsNullOrWhiteSpace(adminUserName) ||
                string.IsNullOrWhiteSpace(adminEmail) ||
                string.IsNullOrWhiteSpace(adminPassword))
            {
                throw new InvalidOperationException(
                    "Thiếu cấu hình AdminBootstrap trong User Secrets");
            }

            adminUserName = adminUserName.Trim();
            adminEmail = adminEmail.Trim();

            // Khong nang quyen tai khoan da ton tai
            var existingUserName =
                await userManager.FindByNameAsync(adminUserName);

            var existingEmail =
                await userManager.FindByEmailAsync(adminEmail);

            if (existingUserName != null ||
                existingEmail != null)
            {
                throw new InvalidOperationException(
                    "Tên đăng nhập hoặc email quản trị viên đã tồn tại. " +
                    "Không thể tự động nâng quyền tài khoản.");
            }

            // Dam bao tao user va gan role
            // trong cung mot transaction
            await using var transaction =
                await db.Database.BeginTransactionAsync();

            // Tao tai khoan Admin dau tien
            var admin = new ApplicationUser
            {
                UserName = adminUserName,
                Email = adminEmail,
                FullName = "Quản trị viên Chấm Công Thông Minh",

                // Ngoai le chi danh cho Admin bootstrap
                EmailConfirmed = true,
                IsActive = true,

                CreatedAtUtc = DateTime.UtcNow
            };

            // Tao Admin qua ASP.NET Core Identity
            var createResult =
                await userManager.CreateAsync(
                    admin, adminPassword);

            if (!createResult.Succeeded)
            {
                var errors = string.Join(", ",
                    createResult.Errors
                        .Select(e => e.Description));

                throw new InvalidOperationException(
                    $"Không tạo được tài khoản quản trị viên: {errors}");
            }

            // Gan role Admin
            var roleResult =
                await userManager.AddToRoleAsync(
                    admin, "Admin");

            if (!roleResult.Succeeded)
            {
                var errors = string.Join(", ",
                    roleResult.Errors
                        .Select(e => e.Description));

                throw new InvalidOperationException(
                    $"Không gán được vai trò quản trị viên: {errors}");
            }

            // Hoan tat transaction
            await transaction.CommitAsync();

            app.Logger.LogInformation(
                "Đã khởi tạo tài khoản quản trị viên đầu tiên.");
        }
        else
        {
            // Neu Admin da ton tai thi khong tao lai
            app.Logger.LogInformation(
                "Quản trị viên đã tồn tại. Bỏ qua AdminBootstrap.");
        }
    }
}

// ========================================
// 12. CAU HINH SWAGGER
// ========================================

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// ========================================
// 13. CAU HINH MIDDLEWARE
// ========================================

// Development cho phep frontend cuc bo; Production chi cho phep origin da cau hinh.
app.UseCors("Frontend");

// Chuyen huong HTTPS chi khi khong phai moi truong Development
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// Xac thuc nguoi dung bang JWT
app.UseAuthentication();

// Kiem tra quyen truy cap
app.UseAuthorization();

// Anh xa API Controllers
app.MapControllers();
app.MapHealthChecks("/health");

// ========================================
// 14. CHAY WEB API
// ========================================

app.Run();
