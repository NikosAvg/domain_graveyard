const std = @import("std");

const messages = [_][]const u8{
    "Ran out of venture capital.",
    "Killed by a pivot.",
    "Victim of scope creep.",
    "Forgot to renew.",
    "Destroyed by AI hype.",
    "Another casualty of Web3.",
    "Died waiting for users.",
    "The landing page survived longer than the company.",
};

pub fn generate(domain: []const u8) []const u8 {
    var hash: u64 = 5381;

    for (domain) |c| {
        hash = ((hash << 5) + hash) + c;
    }

    return messages[hash % messages.len];
}
