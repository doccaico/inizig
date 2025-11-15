const std = @import("std");
const mem = std.mem;

const Section = @This();

allocator: mem.Allocator,
properties: std.StringHashMap([]const u8),

pub fn init(allocator: mem.Allocator) Section {
    return Section{
        .allocator = allocator,
        .properties = std.StringHashMap([]const u8).init(allocator),
    };
}

pub fn deinit(self: *Section) void {
    self.properties.deinit();
}

pub fn setProperty(self: *Section, name: []const u8, value: []const u8) !void {
    try self.properties.put(name, value);
}

pub fn getProperty(self: Section, name: []const u8) ?[]const u8 {
    return self.properties.get(name);
}

pub fn hasProperty(self: Section, name: []const u8) bool {
    return self.properties.contains(name);
}

pub fn deleteProperty(self: *Section, name: []const u8) bool {
    return self.properties.remove(name);
}

test "test section" {
    var section = Section.init(std.testing.allocator);
    defer section.deinit();

    try section.setProperty("name", "joe");
    try section.setProperty("sex", "man");
    try section.setProperty("age", "67");

    try std.testing.expect(section.hasProperty("name"));
    try std.testing.expect(!section.hasProperty("hobby"));

    try std.testing.expectEqual(section.getProperty("name"), "joe");
    try std.testing.expectEqual(section.getProperty("hobby"), null);

    try std.testing.expect(section.deleteProperty("name"));
    try std.testing.expect(!section.deleteProperty("name"));
}
