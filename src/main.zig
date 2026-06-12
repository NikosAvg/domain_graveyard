const std = @import("std");
const server = @import("server.zig");

pub fn main() !void {
    var gpa =
        std.heap.GeneralPurposeAllocator(
            .{},
        ){};

    defer _ = gpa.deinit();

    try server.run(
        gpa.allocator(),
    );
}
