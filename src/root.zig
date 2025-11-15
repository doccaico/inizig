test {
    @import("std").testing.refAllDecls(@This());
}

pub const init = @import("Ini.zig").init;
