const std = @import("std");

const templates = @import("templates.zig");
const rdap = @import("rdap.zig");
const epitaphs = @import("epitaphs.zig");

pub fn run(
    allocator: std.mem.Allocator,
) !void {
    const address =
        try std.net.Address.parseIp(
            "0.0.0.0",
            8080,
        );

    var server =
        try address.listen(.{
            .reuse_address = true,
        });

    defer server.deinit();

    std.debug.print(
        "Listening on http://localhost:8080\n",
        .{},
    );

    while (true) {
        const conn =
            try server.accept();

        defer conn.stream.close();

        var buffer: [8192]u8 = undefined;

        const len =
            try conn.stream.read(&buffer);

        const request =
            buffer[0..len];

        if (std.mem.startsWith(u8, request, "GET / ")) {
            const html =
                try templates.home(
                    allocator,
                );

            defer allocator.free(html);

            try writeHtml(
                conn.stream.writer(),
                html,
            );
        } else {
            const html =
                "<h1>404</h1>";

            try writeHtml(
                conn.stream.writer(),
                html,
            );
        }
    }
}

fn writeHtml(
    writer: anytype,
    body: []const u8,
) !void {
    try writer.print(
        "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: text/html\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n",
        .{body.len},
    );

    try writer.writeAll(body);
}
