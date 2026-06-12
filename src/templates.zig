const std = @import("std");
const models = @import("models.zig");

pub fn home(
    allocator: std.mem.Allocator,
) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<title>Domain Graveyard</title>
        \\<link rel="stylesheet" href="/static/style.css">
        \\</head>
        \\<body>
        \\<div class="container">
        \\<h1>🪦 Domain Graveyard</h1>
        \\<p>Search for forgotten domains.</p>
        \\<form action="/lookup">
        \\<input name="domain">
        \\<button>Dig Up Domain</button>
        \\</form>
        \\</div>
        \\</body>
        \\</html>
    , .{});
}

pub fn results(
    allocator: std.mem.Allocator,
    record: models.DomainRecord,
    epitaph: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<title>{s}</title>
        \\<link rel="stylesheet" href="/static/style.css">
        \\</head>
        \\<body>
        \\<div class="container">
        \\<h1>{s}</h1>
        \\
        \\<div class="epitaph">
        \\{s}
        \\</div>
        \\
        \\<ul>
        \\<li>Registrar: {s}</li>
        \\<li>Status: {s}</li>
        \\<li>Expiration: {s}</li>
        \\</ul>
        \\
        \\<a href="/">← Back</a>
        \\</div>
        \\</body>
        \\</html>
    ,
        .{
            record.domain,
            record.domain,
            epitaph,
            record.registrar orelse "unknown",
            record.status orelse "unknown",
            record.expiration orelse "unknown",
        },
    );
}
