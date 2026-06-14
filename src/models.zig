pub const DomainRecord = struct {
    domain: []const u8,
    registrar: ?[]const u8,
    status: ?[]const u8,
    expiration: ?[]const u8,
    found: bool,
};
