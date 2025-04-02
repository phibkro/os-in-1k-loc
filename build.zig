const std = @import("std");

const name = "osz";

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const main = b.path("src/kernel.zig");
    const exe = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = main,
        .target = target,
        .optimize = .ReleaseSmall,
        .strip = false,
    });

    exe.entry = .disabled;

    exe.setLinkerScript(b.path("src/kernel.ld"));

    b.installArtifact(exe);

    const run_cmd = b.addSystemCommand(&.{"qemu-system-riscv32"});

    run_cmd.addArgs(&.{ "-machine", "virt", "-bios", "default", "-serial", "mon:stdio", "-no-reboot", "-nographic", "-kernel" });

    run_cmd.addArtifactArg(exe);

    // run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run QEMU");
    run_step.dependOn(&run_cmd.step);
}
