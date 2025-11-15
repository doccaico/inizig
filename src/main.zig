const std = @import("std");

const ini = @import("inizig");

const is_debug = switch (@import("builtin").mode) {
    .Debug => true,
    .ReleaseFast, .ReleaseSmall, .ReleaseSafe => false,
};

pub fn main() !void {
    const s =
        \\
        \\[general]
        \\appname = iniparser
        \\version = 0.1
        \\
        \\[author]
        \\name = joe
        \\email = joe@gmail.com
        \\
        \\
    ;

    var debug_allocator: if (is_debug) std.heap.DebugAllocator(.{}) else void = if (is_debug) .init else {};
    const gpa = if (is_debug) debug_allocator.allocator() else std.heap.smp_allocator;
    defer {
        if (is_debug) _ = debug_allocator.deinit();
    }

    var ini_data = ini.init(gpa);
    defer ini_data.deinit();

    try ini_data.parse(s);

    try std.testing.expect(ini_data.hasSection("general"));
    try std.testing.expect(ini_data.hasProperty("general", "appname"));
    try std.testing.expect(ini_data.hasProperty("general", "version"));

    try std.testing.expect(ini_data.hasSection("author"));
    try std.testing.expect(ini_data.hasProperty("author", "name"));
    try std.testing.expect(ini_data.hasProperty("author", "email"));

    const str = try ini_data.stringify();
    defer ini_data.allocator.free(str);
    std.debug.print("{s}\n", .{str});
}
