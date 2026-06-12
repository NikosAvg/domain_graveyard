const models = @import("models.zig");

pub fn lookup(domain: []const u8) !models.DomainRecord {
    return .{
        .domain = domain,
        .registrar = "Ghost Registrar LLC",
        .status = "inactive",
        .expiration = "2025-03-15",
        .found = true,
    };
}
