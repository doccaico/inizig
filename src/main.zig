const builtin = @import("builtin");
const std = @import("std");

const ini = @import("inizig");

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

    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const gpa = switch (builtin.mode) {
        .Debug => debug_allocator.allocator(),
        .ReleaseFast, .ReleaseSmall, .ReleaseSafe => std.heap.smp_allocator,
    };

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
