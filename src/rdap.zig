const std = @import("std");
const models = @import("models.zig");

const Json = std.json.Value;

fn getTld(domain: []const u8) []const u8 {
    var i = domain.len;
    while (i > 0) : (i -= 1) {
        if (domain[i - 1] == '.') return domain[i..];
    }
    return domain;
}

fn buildUrl(allocator: std.mem.Allocator, domain: []const u8) ![]u8 {
    const tld = getTld(domain);

    const base =
        if (std.mem.eql(u8, tld, "com"))
            "https://rdap.verisign.com/com/v1/domain/"
        else if (std.mem.eql(u8, tld, "net"))
            "https://rdap.verisign.com/net/v1/domain/"
        else if (std.mem.eql(u8, tld, "org"))
            "https://rdap.verisign.com/org/v1/domain/"
        else
            return error.UnsupportedTld;

    return std.fmt.allocPrint(allocator, "{s}{s}", .{ base, domain });
}

fn getString(val: Json) ?[]const u8 {
    return switch (val) {
        .string => |s| s,
        else => null,
    };
}

fn findExpiration(allocator: std.mem.Allocator, root: Json) []const u8 {
    const obj = root.object;

    const events = obj.get("events") orelse return "unknown";
    if (events != .array) return "unknown";

    for (events.array.items) |ev| {
        if (ev != .object) continue;

        const action = ev.object.get("eventAction") orelse continue;
        const date = ev.object.get("eventDate") orelse continue;

        if (getString(action)) |a| {
            if (std.mem.eql(u8, a, "expiration")) {
                if (getString(date)) |d| {
                    return allocator.dupe(u8, d) catch "unknown";
                }
            }
        }
    }

    return "unknown";
}

fn findStatus(allocator: std.mem.Allocator, root: Json) []const u8 {
    const obj = root.object;
    const status = obj.get("status") orelse return "unknown";

    if (status != .array) return "unknown";

    for (status.array.items) |s| {
        if (getString(s)) |str| {
            if (std.mem.indexOf(u8, str, "active") != null) {
                return allocator.dupe(u8, "active") catch "active";
            }
        }
    }

    return allocator.dupe(u8, "inactive") catch "inactive";
}

fn findRegistrar(allocator: std.mem.Allocator, root: std.json.Value) []const u8 {
    const obj = root.object;

    const entities = obj.get("entities") orelse return "unknown";
    if (entities != .array) return "unknown";

    for (entities.array.items) |e| {
        if (e != .object) continue;

        const roles = e.object.get("roles") orelse continue;
        if (roles != .array) continue;

        var is_registrar = false;

        for (roles.array.items) |r| {
            if (r == .string and std.mem.eql(u8, r.string, "registrar")) {
                is_registrar = true;
            }
        }

        if (!is_registrar) continue;

        const vcard = e.object.get("vcardArray") orelse return "unknown";
        if (vcard != .array) return "unknown";

        // vcardArray = ["vcard", [...fields...]]
        if (vcard.array.items.len < 2) return "unknown";

        const fields = vcard.array.items[1];
        if (fields != .array) return "unknown";

        for (fields.array.items) |field| {
            if (field != .array) continue;
            if (field.array.items.len < 4) continue;

            const key = field.array.items[0];
            const value = field.array.items[3];

            if (key == .string and value == .string) {
                if (std.mem.eql(u8, key.string, "fn")) {
                    return allocator.dupe(u8, value.string) catch "unknown";
                }
            }
        }
    }

    return "unknown";
}

pub fn lookup(
    allocator: std.mem.Allocator,
    domain: []const u8,
) !models.DomainRecord {
    const url = try buildUrl(allocator, domain);
    defer allocator.free(url);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var header_buf: [8192]u8 = undefined;

    var req = try client.open(
        .GET,
        try std.Uri.parse(url),
        .{
            .server_header_buffer = &header_buf,
        },
    );
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const body = try req.reader().readAllAlloc(
        allocator,
        1024 * 1024,
    );
    defer allocator.free(body);

    var parsed = try std.json.parseFromSlice(
        Json,
        allocator,
        body,
        .{},
    );
    defer parsed.deinit();

    const root = parsed.value;

    return .{
        .domain = domain,
        .registrar = findRegistrar(allocator, root),
        .status = findStatus(allocator, root),
        .expiration = findExpiration(allocator, root),
        .found = true,
    };
}
