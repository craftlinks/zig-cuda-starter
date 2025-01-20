const std = @import("std");

extern fn cudaMalloc(ptr: *?*anyopaque, size: usize) c_int;
extern fn cudaMemcpy(dest: *anyopaque, src: *const anyopaque, size: usize, kind: c_int) c_int;
extern fn cudaFree(ptr: *anyopaque) c_int;
extern "C" fn launchAddKernel(a: *anyopaque, b: *anyopaque, c: *anyopaque) void;

const cudaMemcpyHostToDevice = 1;
const cudaMemcpyDeviceToHost = 2;

export fn add(a: i32, b: i32) i32 {
    var d_a: ?*anyopaque = undefined;
    var d_b: ?*anyopaque = undefined;
    var d_c: ?*anyopaque = undefined;
    var result: i32 = undefined;

    _ = cudaMalloc(&d_a, @sizeOf(i32));
    _ = cudaMalloc(&d_b, @sizeOf(i32));
    _ = cudaMalloc(&d_c, @sizeOf(i32));

    _ = cudaMemcpy(d_a.?, &a, @sizeOf(i32), cudaMemcpyHostToDevice);
    _ = cudaMemcpy(d_b.?, &b, @sizeOf(i32), cudaMemcpyHostToDevice);

    launchAddKernel(d_a.?, d_b.?, d_c.?);

    _ = cudaMemcpy(&result, d_c.?, @sizeOf(i32), cudaMemcpyDeviceToHost);

    _ = cudaFree(d_a.?);
    _ = cudaFree(d_b.?);
    _ = cudaFree(d_c.?);

    return result;
}

pub fn main() void {
    const num1: i32 = 5;
    const num2: i32 = 3;
    const result = add(num1, num2);
    std.debug.print("Result of {d} + {d} = {d}\n", .{ num1, num2, result });
}

test "basic addition" {
    try std.testing.expectEqual(@as(i32, 4), add(2, 2));
    try std.testing.expectEqual(@as(i32, 0), add(0, 0));
    try std.testing.expectEqual(@as(i32, -2), add(-5, 3));
}
