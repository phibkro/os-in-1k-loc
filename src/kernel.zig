const std = @import("std");
const sbi = @import("common.zig");
/// We can also declare it as extern char __bss;,
/// but __bss alone means "the value at the 0th byte of the .bss section"
/// instead of "the start address of the .bss section".
/// Therefore, it is recommended to add [] to ensure that __bss
/// returns an address and prevent any careless mistakes.
const bss = @extern([*]u8, .{ .name = "__bss" });
const bss_end = @extern([*]u8, .{ .name = "__bss_end" });
const stack_top = @extern([*]u8, .{ .name = "__stack_top" });

fn write_fn(_: *const anyopaque, bytes: []const u8) !usize {
    for (bytes) |c| {
        _ = sbi.put_char(c);
    }
    return bytes.len;
}

const console: std.io.AnyWriter = .{
    .context = undefined,
    .writeFn = write_fn,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    console.print("PANIC: {s}\n", .{msg}) catch {};
    while (true) asm volatile ("wfi");
}

export fn kernel_main() noreturn {
    // The .bss section is first initialized to zero using the memset function.
    // Although some bootloaders may recognize and zero-clear the .bss section,
    // but we initialize it manually just in case.
    const bss_len = @intFromPtr(bss) - @intFromPtr(bss_end);
    @memset(bss[0..bss_len], 0);

    const hello = "\n\nhello kernel!\n";

    console.print(hello, .{}) catch {};

    // Finally, the function enters an infinite loop and the kernel terminates.
    while (true) asm volatile ("wfi");
}

/// The __attribute__((naked)) attribute
/// instructs the compiler not to generate unnecessary code
/// before and after the function body,
/// such as a return instruction.
/// This ensures that the inline assembly code is the exact function body.
///
/// The __attribute__((section(".text.boot"))) attribute,
/// which controls the placement of the function in the linker script.
/// Since OpenSBI simply jumps to 0x80200000 without knowing the entry point,
/// the boot function needs to be placed at 0x80200000.
export fn boot() linksection(".text.boot") callconv(.Naked) void {
    asm volatile (
        \\mv sp, %[stack_top]
        \\j kernel_main
        :
        : [stack_top] "r" (stack_top),
    );
}
