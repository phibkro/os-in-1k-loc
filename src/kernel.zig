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

export fn kernel_main() noreturn {
    main() catch |err| {
        std.debug.panic("kernel_main: {s}\n", .{@errorName(err)}) catch {};
    };

    // Finally, the function enters an infinite loop and the kernel terminates.
    while (true) asm volatile ("wfi");
}

fn main() !void {
    // The .bss section is first initialized to zero using the memset function.
    // Although some bootloaders may recognize and zero-clear the .bss section,
    // but we initialize it manually just in case.
    const bss_len = @intFromPtr(bss) - @intFromPtr(bss_end);
    @memset(bss[0..bss_len], 0);

    // Trap handling
    write_csr("stvec", @intFromPtr(&kernel_entry));
    defer asm volatile ("unimp");

    // Printing to console
    const hello = "\n\nhello kernel!\n";
    try console.print(hello, .{});

    // Memory allocation
    const paddr0 = try alloc_page(2);
    const paddr1 = try alloc_page(1);
    try console.print("alloc_pages test: paddr0={*}\n", .{paddr0});
    try console.print("alloc_pages test: paddr1={*}\n", .{paddr1});

    // @panic("booted!");
}

export fn kernel_entry() align(4) callconv(.Naked) void {
    asm volatile (
        \\csrw sscratch, sp
        \\addi sp, sp, -4 * 31
        \\sw ra,  4 * 0(sp)
        \\sw gp,  4 * 1(sp)
        \\sw tp,  4 * 2(sp)
        \\sw t0,  4 * 3(sp)
        \\sw t1,  4 * 4(sp)
        \\sw t2,  4 * 5(sp)
        \\sw t3,  4 * 6(sp)
        \\sw t4,  4 * 7(sp)
        \\sw t5,  4 * 8(sp)
        \\sw t6,  4 * 9(sp)
        \\sw a0,  4 * 10(sp)
        \\sw a1,  4 * 11(sp)
        \\sw a2,  4 * 12(sp)
        \\sw a3,  4 * 13(sp)
        \\sw a4,  4 * 14(sp)
        \\sw a5,  4 * 15(sp)
        \\sw a6,  4 * 16(sp)
        \\sw a7,  4 * 17(sp)
        \\sw s0,  4 * 18(sp)
        \\sw s1,  4 * 19(sp)
        \\sw s2,  4 * 20(sp)
        \\sw s3,  4 * 21(sp)
        \\sw s4,  4 * 22(sp)
        \\sw s5,  4 * 23(sp)
        \\sw s6,  4 * 24(sp)
        \\sw s7,  4 * 25(sp)
        \\sw s8,  4 * 26(sp)
        \\sw s9,  4 * 27(sp)
        \\sw s10, 4 * 28(sp)
        \\sw s11, 4 * 29(sp)
        \\
        \\csrr a0, sscratch
        \\sw a0, 4 * 30(sp)
        \\
        \\mv a0, sp
        \\call handle_trap
        \\
        \\lw ra,  4 * 0(sp)
        \\lw gp,  4 * 1(sp)
        \\lw tp,  4 * 2(sp)
        \\lw t0,  4 * 3(sp)
        \\lw t1,  4 * 4(sp)
        \\lw t2,  4 * 5(sp)
        \\lw t3,  4 * 6(sp)
        \\lw t4,  4 * 7(sp)
        \\lw t5,  4 * 8(sp)
        \\lw t6,  4 * 9(sp)
        \\lw a0,  4 * 10(sp)
        \\lw a1,  4 * 11(sp)
        \\lw a2,  4 * 12(sp)
        \\lw a3,  4 * 13(sp)
        \\lw a4,  4 * 14(sp)
        \\lw a5,  4 * 15(sp)
        \\lw a6,  4 * 16(sp)
        \\lw a7,  4 * 17(sp)
        \\lw s0,  4 * 18(sp)
        \\lw s1,  4 * 19(sp)
        \\lw s2,  4 * 20(sp)
        \\lw s3,  4 * 21(sp)
        \\lw s4,  4 * 22(sp)
        \\lw s5,  4 * 23(sp)
        \\lw s6,  4 * 24(sp)
        \\lw s7,  4 * 25(sp)
        \\lw s8,  4 * 26(sp)
        \\lw s9,  4 * 27(sp)
        \\lw s10, 4 * 28(sp)
        \\lw s11, 4 * 29(sp)
        \\lw sp,  4 * 30(sp)
        \\sret
    );
}

// Memory allocation

const free_ram = @extern([*]u8, .{ .name = "__free_ram" });
const free_ram_end = @extern([*]u8, .{ .name = "__free_ram_end" });

var next_paddr = free_ram;

fn alloc_page(n: usize) ![*]u8 {
    const paddr = next_paddr;
    next_paddr += n * sbi.PAGE_SIZE;

    if (@intFromPtr(next_paddr) > @intFromPtr(free_ram_end)) {
        return error.OutOfMemory;
    }

    @memset(paddr[0 .. n * sbi.PAGE_SIZE], 0);

    return paddr;
}

// Trap handling

export fn handle_trap(trap_frame: *const TrapFrame) void {
    _ = trap_frame;

    const scause = read_csr("scause"); // mcause
    const stval = read_csr("stval"); // mepc
    const user_pc = read_csr("sepc"); // utvec

    std.debug.panic("Unexpected trap scause={x}, stval={x}, sepc={x}\n", .{ scause, stval, user_pc });
}

fn read_csr(comptime reg: []const u8) usize {
    return asm ("csrr %[ret], " ++ reg
        : [ret] "=r" (-> usize),
    );
}

fn write_csr(comptime reg: []const u8, val: usize) void {
    asm volatile ("csrw " ++ reg ++ ", %[val]"
        :
        : [val] "r" (val),
    );
}

const TrapFrame = extern struct {
    ra: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s0: usize,
    s1: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    sp: usize,
};

// Panic

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    console.print("PANIC: {s}\n", .{msg}) catch {};
    while (true) asm volatile ("wfi");
}

// Printing to console

const console: std.io.AnyWriter = .{
    .context = undefined,
    .writeFn = write_fn,
};

fn write_fn(_: *const anyopaque, bytes: []const u8) !usize {
    for (bytes) |c| {
        _ = sbi.put_char(c);
    }
    return bytes.len;
}
