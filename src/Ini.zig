const std = @import("std");
const ascii = std.ascii;
const mem = std.mem;

const Section = @import("Section.zig");

const Ini = @This();

allocator: mem.Allocator,
sections: std.StringHashMap(Section),

pub fn init(allocator: mem.Allocator) Ini {
    return Ini{
        .allocator = allocator,
        .sections = std.StringHashMap(Section).init(allocator),
    };
}

pub fn deinit(self: *Ini) void {
    var it = self.sections.valueIterator();
    while (it.next()) |section| {
        section.deinit();
    }
    self.sections.deinit();
}

pub fn setSection(self: *Ini, name: []const u8) !void {
    if (self.hasSection(name)) {
        return error.DuplicatedSection;
    }
    const section = Section.init(self.allocator);
    try self.sections.put(name, section);
}

pub fn countSection(self: Ini) std.StringHashMap(Section).Size {
    return self.sections.count();
}

pub fn hasSection(self: Ini, name: []const u8) bool {
    return self.sections.contains(name);
}

pub fn deleteSection(self: *Ini, name: []const u8) bool {
    return self.sections.remove(name);
}

pub fn countProperty(self: Ini, sectionName: []const u8) !std.StringHashMap(Section).Size {
    if (self.sections.get(sectionName)) |section| {
        return section.countProperty();
    }
    return error.SectionNotFound;
}

pub fn hasProperty(self: Ini, sectionName: []const u8, key: []const u8) bool {
    if (self.sections.get(sectionName)) |section| {
        return section.hasProperty(key);
    }
    return false;
}

pub fn setProperty(self: Ini, sectionName: []const u8, key: []const u8, value: []const u8) !void {
    if (!self.hasSection(sectionName)) {
        return error.SectionNotFound;
    }
    const section = self.sections.getPtr(sectionName).?;
    try section.setProperty(key, value);
}

pub fn getProperty(self: Ini, sectionName: []const u8, key: []const u8) !?[]const u8 {
    if (self.sections.get(sectionName)) |section| {
        return section.getProperty(key);
    }
    return error.SectionNotFound;
}

pub fn deleteProperty(self: *Ini, sectionName: []const u8, key: []const u8) !bool {
    if (!self.hasSection(sectionName)) {
        return error.SectionNotFound;
    }
    const section = self.sections.getPtr(sectionName).?;
    return section.deleteProperty(key);
}

pub fn parse(self: *Ini, s: []const u8) !void {
    const ParserState = enum {
        readSection,
        readKV,
    };
    var state: ParserState = .readSection;
    var current_section_name: []const u8 = "";
    var lines = mem.splitSequence(u8, s, "\n");

    while (lines.next()) |raw_line| {
        const line = mem.trim(u8, raw_line, &ascii.whitespace);
        if (mem.eql(u8, "", line) or mem.startsWith(u8, line, ";") or mem.startsWith(u8, line, "#")) {
            continue;
        }
        if (mem.startsWith(u8, line, "[") and mem.endsWith(u8, line, "]")) {
            state = .readSection;
        }

        if (state == .readSection) {
            current_section_name = line[1 .. line.len - 1];
            try self.setSection(current_section_name);
            state = .readKV;
            continue;
        }

        if (state == .readKV) {
            var parts = mem.splitSequence(u8, line, "=");

            // counting
            var count: i32 = 0;
            while (parts.next()) |_| {
                count += 1;
            }
            parts.reset();

            if (count == 2) {
                const key = mem.trim(u8, parts.first(), &ascii.whitespace);
                const val = mem.trim(u8, parts.next().?, &ascii.whitespace);
                try self.setProperty(current_section_name, key, val);
            }
        }
    }
}

pub fn stringify(self: Ini) ![]u8 {
    var wa = std.Io.Writer.Allocating.init(self.allocator);
    defer wa.deinit();

    const writer = &wa.writer;

    var section_key_iterator = self.sections.keyIterator();
    while (section_key_iterator.next()) |section_key| {
        try writer.print("[{s}]\n", .{section_key.*});

        const section = self.sections.get(section_key.*).?;

        var property_iterator = section.properties.iterator();
        while (property_iterator.next()) |entry| {
            try writer.print("{s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
    return try wa.toOwnedSlice();
}

test "ini" {
    var ini = Ini.init(std.testing.allocator);
    defer ini.deinit();

    // setSection
    try ini.setSection("Person");
    try std.testing.expectError(error.DuplicatedSection, ini.setSection("Person"));

    // countSection
    try std.testing.expectEqual(1, ini.countSection());

    // hasSection
    try std.testing.expect(ini.hasSection("Person"));
    try std.testing.expect(!ini.hasSection("Cat"));

    // deleteSection
    try std.testing.expect(!ini.deleteSection("Cat"));
    try std.testing.expect(ini.deleteSection("Person"));

    try ini.setSection("Person");

    // setProperty
    try ini.setProperty("Person", "name", "joe");
    try ini.setProperty("Person", "sex", "man");
    try ini.setProperty("Person", "age", "67");
    try std.testing.expectError(error.SectionNotFound, ini.setProperty("Cat", "name", "lilly"));

    // getProperty
    try std.testing.expectEqual(try ini.getProperty("Person", "name"), "joe");
    try std.testing.expectError(error.SectionNotFound, ini.getProperty("cat", "name"));
    try std.testing.expectEqual(try ini.getProperty("Person", "hobby"), null);

    // countProperty
    try std.testing.expectEqual(3, ini.countProperty("Person"));

    // hasProperty
    try std.testing.expect(ini.hasProperty("Person", "name"));
    try std.testing.expect(!ini.hasProperty("Person", "hobby"));
    try std.testing.expect(!ini.hasProperty("Cat", "name"));

    // deleteProperty
    try std.testing.expectError(error.SectionNotFound, ini.deleteProperty("Cat", "name"));
    try std.testing.expect(!try ini.deleteProperty("Person", "hobby"));
    try std.testing.expect(try ini.deleteProperty("Person", "age"));

    try std.testing.expectEqual(2, ini.countProperty("Person"));
}

test "create an ini" {
    var ini = Ini.init(std.testing.allocator);
    defer ini.deinit();

    try ini.setSection("Person");
    try ini.setProperty("Person", "name", "joe");
    try ini.setProperty("Person", "sex", "man");
    try ini.setProperty("Person", "age", "67");
}

test "parse an ini" {
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

    var ini = Ini.init(std.testing.allocator);
    defer ini.deinit();

    try ini.parse(s);

    try std.testing.expect(ini.hasSection("general"));
    try std.testing.expect(ini.hasProperty("general", "appname"));
    try std.testing.expect(ini.hasProperty("general", "version"));

    try std.testing.expect(ini.hasSection("author"));
    try std.testing.expect(ini.hasProperty("author", "name"));
    try std.testing.expect(ini.hasProperty("author", "email"));

    // const str = try ini.stringify();
    // defer ini.allocator.free(str);
    // std.debug.print("{s}\n", .{str});
}
