pub const page_size = 4096;

const SbiRet = struct { err: usize, value: usize };
fn sbi_call(
    arg0: usize,
    arg1: usize,
    arg2: usize,
    arg3: usize,
    arg4: usize,
    arg5: usize,
    /// SBI Function ID
    fid: usize,
    /// SBI Extension ID
    eid: usize,
) SbiRet {
    var err: usize = undefined;
    var value: usize = undefined;

    asm volatile ("ecall"
        : [err] "={a0}" (err),
          [value] "={a1}" (value),
        : [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
          [arg3] "{a3}" (arg3),
          [arg4] "{a4}" (arg4),
          [arg5] "{a5}" (arg5),
          [arg6] "{a6}" (fid),
          [arg7] "{a7}" (eid),
        : "memory"
    );

    return .{ .err = err, .value = value };
}

pub fn put_char(c: u8) void {
    _ = sbi_call(c, 0, 0, 0, 0, 0, 0, 1);
}
