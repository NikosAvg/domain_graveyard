const std = @import("std");

const templates = @import("templates.zig");
const rdap = @import("rdap.zig");
const epitaphs = @import("epitaphs.zig");

fn getPath(request: []const u8) []const u8 {
    const first_line_end =
        std.mem.indexOf(u8, request, "\r\n") orelse request.len;

    const first_line =
        request[0..first_line_end];

    var parts =
        std.mem.splitScalar(u8, first_line, ' ');

    _ = parts.next(); // GET
    return parts.next() orelse "/";
}

fn getDomainParam(path: []const u8) ?[]const u8 {
    const qmark =
        std.mem.indexOfScalar(u8, path, '?') orelse return null;

    const query = path[qmark + 1 ..];

    var iter =
        std.mem.splitScalar(u8, query, '&');

    while (iter.next()) |pair| {
        if (std.mem.startsWith(u8, pair, "domain=")) {
            return pair[7..];
        }
    }

    return null;
}

fn serveStatic(writer: anytype, path: []const u8) !bool {
    if (std.mem.eql(u8, path, "/static/style.css")) {
        const css = @embedFile("static/style.css");

        try writer.print(
            "HTTP/1.1 200 OK\r\n" ++
                "Content-Type: text/css\r\n" ++
                "Content-Length: {}\r\n" ++
                "\r\n{s}",
            .{ css.len, css },
        );

        return true;
    }

    return false;
}

fn writeHtml(
    writer: anytype,
    status: []const u8,
    body: []const u8,
) !void {
    try writer.print(
        "HTTP/1.1 {s}\r\n" ++
            "Content-Type: text/html\r\n" ++
            "Content-Length: {}\r\n" ++
            "\r\n{s}",
        .{ status, body.len, body },
    );
}

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

        const path =
            getPath(request);

        // -------------------------
        // STATIC FILES
        // -------------------------
        if (try serveStatic(conn.stream.writer(), path)) {
            continue;
        }

        // -------------------------
        // HOME PAGE
        // -------------------------
        if (std.mem.eql(u8, path, "/")) {
            const html =
                try templates.home(allocator);

            defer allocator.free(html);

            try writeHtml(
                conn.stream.writer(),
                "200 OK",
                html,
            );

            continue;
        }

        // -------------------------
        // LOOKUP
        // -------------------------
        if (std.mem.startsWith(u8, path, "/lookup")) {
            const domain =
                getDomainParam(path) orelse "unknown";

            const record =
                try rdap.lookup(allocator, domain);

            const epitaph =
                epitaphs.generate(domain);

            const html =
                try templates.results(
                    allocator,
                    record,
                    epitaph,
                );

            defer allocator.free(html);

            try writeHtml(
                conn.stream.writer(),
                "200 OK",
                html,
            );

            continue;
        }

        // -------------------------
        // 404
        // -------------------------
        try writeHtml(
            conn.stream.writer(),
            "404 Not Found",
            "<h1>404 Not Found</h1>",
        );
    }
}
