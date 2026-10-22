
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using ChamCong_PhanHuuVinh_2380602565_API.Models;

namespace ChamCong_PhanHuuVinh_2380602565_API.Data
{
    public class ApplicationDbContext
        : IdentityDbContext<ApplicationUser>
    {
        public ApplicationDbContext(
            DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        // 1. Khai báo các bảng nghiệp vụ
        public DbSet<Department> Departments => Set<Department>();
        public DbSet<Employee> Employees => Set<Employee>();
        public DbSet<WorkLocation> WorkLocations => Set<WorkLocation>();
        public DbSet<Shift> Shifts => Set<Shift>();
        public DbSet<ShiftAssignment> ShiftAssignments => Set<ShiftAssignment>();
        public DbSet<AttendanceRecord> AttendanceRecords => Set<AttendanceRecord>();
        public DbSet<QrSession> QrSessions => Set<QrSession>();
        public DbSet<OtpChallenge> OtpChallenges => Set<OtpChallenge>();
        public DbSet<LocationShare> LocationShares => Set<LocationShare>();
        public DbSet<AttendanceAppeal> AttendanceAppeals => Set<AttendanceAppeal>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Giữ cấu hình các bảng Identity
            base.OnModelCreating(modelBuilder);

            // 2. Nhân viên và tài khoản
            modelBuilder.Entity<Employee>(entity =>
            {
                entity.HasIndex(e => e.EmployeeCode)
                    .IsUnique();

                entity.HasOne(e => e.ApplicationUser)
                    .WithOne()
                    .HasForeignKey<Employee>(e => e.ApplicationUserId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(e => e.Department)
                    .WithMany(d => d.Employees)
                    .HasForeignKey(e => e.DepartmentId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // 3. Phân ca làm việc
            modelBuilder.Entity<ShiftAssignment>(entity =>
            {
                entity.HasIndex(s => new
                {
                    s.EmployeeId,
                    s.WorkDate,
                    s.ShiftId
                }).IsUnique();

                entity.HasOne(s => s.Employee)
                    .WithMany()
                    .HasForeignKey(s => s.EmployeeId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(s => s.Shift)
                    .WithMany()
                    .HasForeignKey(s => s.ShiftId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(s => s.WorkLocation)
                    .WithMany()
                    .HasForeignKey(s => s.WorkLocationId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // 4. Bản ghi chấm công
            modelBuilder.Entity<AttendanceRecord>(entity =>
            {
                entity.HasOne(a => a.ShiftAssignment)
                    .WithOne(s => s.AttendanceRecord)
                    .HasForeignKey<AttendanceRecord>(
                        a => a.ShiftAssignmentId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne<QrSession>()
                    .WithMany()
                    .HasForeignKey(a => a.CheckInQrSessionId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne<QrSession>()
                    .WithMany()
                    .HasForeignKey(a => a.CheckOutQrSessionId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // 5. Mã QR và địa điểm
            modelBuilder.Entity<QrSession>(entity =>
            {
                entity.HasIndex(q => q.TokenHash)
                    .IsUnique();

                entity.HasOne(q => q.WorkLocation)
                    .WithMany()
                    .HasForeignKey(q => q.WorkLocationId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // 6. Xác minh OTP
            modelBuilder.Entity<OtpChallenge>(entity =>
            {
                entity.HasIndex(o => new
                {
                    o.ApplicationUserId,
                    o.Purpose,
                    o.ExpiresAtUtc
                });

                entity.HasOne(o => o.ApplicationUser)
                    .WithMany()
                    .HasForeignKey(o => o.ApplicationUserId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // 7. Lịch sử chia sẻ vị trí
            modelBuilder.Entity<LocationShare>(entity =>
            {
                entity.HasOne(l => l.Employee)
                    .WithMany()
                    .HasForeignKey(l => l.EmployeeId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // 8. Giải trình chấm công
            modelBuilder.Entity<AttendanceAppeal>(entity =>
            {
                // Trạng thái tham gia điều kiện UPDATE để hai quản trị viên
                // không thể đồng thời duyệt lại cùng một yêu cầu.
                entity.Property(a => a.Status)
                    .IsConcurrencyToken();

                entity.HasOne(a => a.Employee)
                    .WithMany()
                    .HasForeignKey(a => a.EmployeeId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(a => a.ShiftAssignment)
                    .WithMany()
                    .HasForeignKey(a => a.ShiftAssignmentId)
                    .OnDelete(DeleteBehavior.NoAction);

                entity.HasOne(a => a.ReviewedByUser)
                    .WithMany()
                    .HasForeignKey(a => a.ReviewedByUserId)
                    .OnDelete(DeleteBehavior.NoAction);
            });
        }
    }
}
